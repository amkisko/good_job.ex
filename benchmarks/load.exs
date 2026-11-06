# Load / resource bench for GoodJob.
#
# Usage:
#   MIX_ENV=dev mix run benchmarks/load.exs
#   JOBS=20000 THREADS=32 LOCK=skiplocked MIX_ENV=dev mix run benchmarks/load.exs
#   SCENARIO=enqueue_only|drain|matrix MIX_ENV=dev mix run benchmarks/load.exs

Code.require_file("benchmarks/support/metrics.exs")

defmodule GoodJob.Bench.NoopJob do
  use GoodJob.Job, queue: "bench"

  @impl GoodJob.Behaviour
  def perform(_args), do: :ok
end

defmodule GoodJob.Bench.Load do
  alias GoodJob.Bench.Metrics
  alias GoodJob.TestRepo

  @default_jobs 5_000
  @default_threads 16

  def run! do
    configure!()
    {:ok, _} = Application.ensure_all_started(:postgrex)
    {:ok, _} = Application.ensure_all_started(:ecto_sql)
    {:ok, _} = TestRepo.start_link()

    migrate!()
    _ = Metrics.attach_query_counter()

    scenario = System.get_env("SCENARIO", "matrix")
    jobs = env_int("JOBS", @default_jobs)
    threads = env_int("THREADS", @default_threads)

    IO.puts("""
    GoodJob load bench
    scenario=#{scenario} jobs=#{jobs} threads=#{threads}
    database=#{Keyword.get(Application.get_env(:good_job, TestRepo), :database)}
    """)

    results =
      case scenario do
        "enqueue_only" ->
          [run_enqueue_only!(jobs)]

        "drain" ->
          lock = lock_strategy!()
          [run_drain!(jobs, threads, lock, bulk?: env_bool("BULK", true))]

        "matrix" ->
          run_matrix!(jobs, threads)

        other ->
          Mix.raise("Unknown SCENARIO=#{inspect(other)}")
      end

    write_results!(results)
    Enum.each(results, &IO.puts(&1.report))
    :ok
  end

  defp run_matrix!(jobs, threads) do
    # Warmup small drain so schema/caches settle.
    _ = run_drain!(500, max(threads, 8), :skiplocked, bulk?: true, label: "warmup")

    enqueue_rows =
      for bulk? <- [false, true] do
        run_enqueue_only!(jobs, bulk?: bulk?)
      end

    drain_rows =
      for lock <- [:advisory, :hybrid, :skiplocked],
          bulk? <- [true],
          listen? <- [true, false] do
        run_drain!(jobs, threads, lock, bulk?: bulk?, listen?: listen?)
      end

    heavy =
      run_drain!(jobs * 2, threads * 2, :skiplocked,
        bulk?: true,
        listen?: false,
        label: "heavy_skiplocked_silent"
      )

    enqueue_rows ++ drain_rows ++ [heavy]
  end

  defp run_enqueue_only!(jobs, opts \\ []) do
    bulk? = Keyword.get(opts, :bulk?, env_bool("BULK", true))
    label = Keyword.get(opts, :label, "enqueue_#{if bulk?, do: "bulk", else: "single"}")

    reset_tables!()
    Metrics.reset_query_count()
    before = Metrics.sample(TestRepo)
    before_queries = Metrics.query_count()
    before_lsn = before.storage.wal_lsn

    {wall_us, _} =
      :timer.tc(fn ->
        if bulk? do
          {:ok, _} =
            GoodJob.Bulk.enqueue(fn ->
              Enum.each(1..jobs, fn i ->
                GoodJob.Bench.NoopJob.enqueue(%{n: i})
              end)
            end)
        else
          Enum.each(1..jobs, fn i ->
            {:ok, _} = GoodJob.Bench.NoopJob.enqueue(%{n: i})
          end)
        end
      end)

    after_sample = Metrics.sample(TestRepo)
    metrics = Metrics.diff(before, after_sample)
    queries = Metrics.query_count() - before_queries
    wal = Metrics.wal_bytes_between(TestRepo, before_lsn, after_sample.storage.wal_lsn)
    cpu_pct = cpu_approx(metrics.beam.runtime_ms, wall_us)

    report =
      Metrics.format_report(label, jobs, %{metrics | wall_ms: div(wall_us, 1000), wall_s: wall_us / 1_000_000}, %{
        queries: queries,
        wal_bytes: wal,
        cpu_pct: cpu_pct
      })

    %{
      label: label,
      kind: :enqueue,
      jobs: jobs,
      wall_us: wall_us,
      jobs_per_s: jobs / (wall_us / 1_000_000),
      queries: queries,
      wal_bytes: wal,
      metrics: metrics,
      report: report
    }
  end

  defp run_drain!(jobs, threads, lock, opts) do
    bulk? = Keyword.get(opts, :bulk?, true)
    listen? = Keyword.get(opts, :listen?, true)

    label =
      Keyword.get(opts, :label, "drain_#{lock}_t#{threads}_bulk#{bulk?}_listen#{listen?}")

    stop_good_job!()
    reset_tables!()

    # :external avoids MIX_ENV=dev forcing poll_interval to -1 (async continuous mode).
    Application.put_env(:good_job, :config, %{
      repo: TestRepo,
      execution_mode: :external,
      queues: "bench",
      max_processes: threads,
      threads: threads,
      poll_interval: 1,
      enable_listen_notify: listen?,
      lock_strategy: lock,
      # Drop finished rows so dequeue indexes stay hot under heavy load.
      preserve_job_records: env_bool("PRESERVE", false),
      cleanup_interval_jobs: 100_000,
      cleanup_interval_seconds: 3600
    })

    # Enqueue first (producer), then start consumers — isolates drain cost.
    enqueue_started = System.monotonic_time(:microsecond)

    if bulk? do
      {:ok, _} =
        GoodJob.Bulk.enqueue(fn ->
          Enum.each(1..jobs, fn i ->
            GoodJob.Bench.NoopJob.enqueue(%{n: i})
          end)
        end)
    else
      Enum.each(1..jobs, fn i ->
        {:ok, _} = GoodJob.Bench.NoopJob.enqueue(%{n: i})
      end)
    end

    enqueue_us = System.monotonic_time(:microsecond) - enqueue_started

    Metrics.reset_query_count()
    before = Metrics.sample(TestRepo)
    before_queries = Metrics.query_count()
    before_lsn = before.storage.wal_lsn
    {runtime0, _} = :erlang.statistics(:runtime)

    {:ok, supervisor} = GoodJob.Supervisor.start_link([])
    # start_link ties the bench process to the supervisor; unlink so shutdown cannot kill us.
    Process.unlink(supervisor)

    wait_until_drained!(jobs, timeout_ms: max(120_000, jobs * 20))

    {runtime1, _} = :erlang.statistics(:runtime)
    after_sample = Metrics.sample(TestRepo)
    metrics = Metrics.diff(before, after_sample)
    queries = Metrics.query_count() - before_queries
    wal = Metrics.wal_bytes_between(TestRepo, before_lsn, after_sample.storage.wal_lsn)
    wall_us = metrics.wall_ms * 1000
    cpu_pct = cpu_approx(runtime1 - runtime0, wall_us)

    unfinished = unfinished_count!()
    finished = finished_count!()

    report =
      Metrics.format_report(label, jobs, metrics, %{
        queries: queries,
        wal_bytes: wal,
        cpu_pct: cpu_pct
      }) <>
        "\nenqueue_prep_s=#{Float.round(enqueue_us / 1_000_000, 3)} finished=#{finished} unfinished=#{unfinished}"

    stop_good_job!()

    %{
      label: label,
      kind: :drain,
      lock: lock,
      threads: threads,
      bulk?: bulk?,
      listen?: listen?,
      jobs: jobs,
      wall_us: wall_us,
      jobs_per_s: if(metrics.wall_s > 0, do: jobs / metrics.wall_s, else: 0.0),
      queries: queries,
      wal_bytes: wal,
      unfinished: unfinished,
      finished: finished,
      metrics: metrics,
      report: report
    }
  end

  defp configure! do
    database = System.get_env("GOOD_JOB_BENCH_DB", "good_job_bench")
    hostname = System.get_env("PGHOST", "localhost")
    username = System.get_env("PGUSER") || System.get_env("USER")
    password = System.get_env("PGPASSWORD")
    port = String.to_integer(System.get_env("PGPORT", "5432"))

    repo_config =
      [
        username: username,
        password: password,
        hostname: hostname,
        port: port,
        database: database,
        pool_size: env_int("POOL_SIZE", 40),
        queue_target: 5_000,
        queue_interval: 1_000,
        log: false,
        priv: "priv",
        show_sensitive_data_on_connection_error: true
      ]
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)

    Application.put_env(:good_job, TestRepo, repo_config)

    Application.put_env(:good_job, :config, %{
      repo: TestRepo,
      execution_mode: :inline,
      queues: "bench",
      max_processes: 1,
      poll_interval: 1,
      enable_listen_notify: false,
      lock_strategy: :skiplocked
    })

    Logger.configure(level: :error)
  end

  defp migrate! do
    migrations = Path.expand("priv/migrations")
    _migrated = Ecto.Migrator.run(TestRepo, migrations, :up, all: true)
    :ok
  end

  defp reset_tables! do
    Ecto.Adapters.SQL.query!(
      TestRepo,
      """
      TRUNCATE
        good_jobs,
        good_job_executions,
        good_job_batches,
        good_job_processes,
        good_job_settings,
        good_job_concurrency_claims
      RESTART IDENTITY CASCADE
      """,
      []
    )
  end

  defp wait_until_drained!(expected, opts) do
    timeout_ms = Keyword.fetch!(opts, :timeout_ms)
    deadline = System.monotonic_time(:millisecond) + timeout_ms

    preserve? = GoodJob.Config.preserve_job_records?() == true

    Stream.repeatedly(fn ->
      unfinished = unfinished_count!()
      finished = if preserve?, do: finished_count!(), else: expected - unfinished
      {finished, unfinished}
    end)
    |> Enum.reduce_while(nil, fn {finished, unfinished}, _ ->
      cond do
        unfinished == 0 and (not preserve? or finished >= expected) ->
          {:halt, :ok}

        System.monotonic_time(:millisecond) > deadline ->
          {:halt, {:timeout, finished, unfinished}}

        true ->
          Process.sleep(50)
          {:cont, nil}
      end
    end)
    |> case do
      :ok ->
        :ok

      {:timeout, finished, unfinished} ->
        sample =
          Ecto.Adapters.SQL.query!(
            TestRepo,
            """
            SELECT COUNT(*) FILTER (WHERE locked_by_id IS NOT NULL) AS locked,
                   COUNT(*) FILTER (WHERE error IS NOT NULL) AS with_error,
                   COUNT(*) FILTER (WHERE scheduled_at > NOW()) AS future,
                   MIN(error) AS sample_error
            FROM good_jobs
            WHERE finished_at IS NULL
            """,
            []
          )

        raise "drain timeout: finished=#{finished} unfinished=#{unfinished} expected=#{expected} sample=#{inspect(sample.rows)}"
    end
  end

  defp unfinished_count! do
    %{rows: [[n]]} =
      Ecto.Adapters.SQL.query!(
        TestRepo,
        """
        SELECT COUNT(*) FROM (
          SELECT 1 FROM good_jobs WHERE finished_at IS NULL LIMIT 100000
        ) AS unfinished
        """,
        []
      )

    n
  end

  defp finished_count! do
    %{rows: [[n]]} =
      Ecto.Adapters.SQL.query!(
        TestRepo,
        "SELECT COUNT(*) FROM good_jobs WHERE finished_at IS NOT NULL",
        []
      )

    n
  end

  defp stop_good_job! do
    case Process.whereis(GoodJob.Supervisor) do
      nil ->
        :ok

      pid ->
        Process.unlink(pid)

        try do
          GoodJob.Supervisor.shutdown(timeout: 2)
        rescue
          _ -> :ok
        catch
          :exit, _ -> :ok
        end

        if Process.alive?(pid) do
          Process.exit(pid, :shutdown)
        end

        Enum.reduce_while(1..50, nil, fn _, _ ->
          if Process.whereis(GoodJob.Supervisor) do
            Process.sleep(20)
            {:cont, nil}
          else
            {:halt, :ok}
          end
        end)
    end

    for name <- [GoodJob.Poller, GoodJob.Notifier, GoodJob.ProcessTracker, GoodJob.Registry, GoodJob.Scheduler.Supervisor] do
      case Process.whereis(name) do
        nil ->
          :ok

        pid ->
          Process.unlink(pid)
          Process.exit(pid, :shutdown)
      end
    end

    Process.sleep(50)
  end

  defp lock_strategy! do
    case System.get_env("LOCK", "skiplocked") do
      "advisory" -> :advisory
      "hybrid" -> :hybrid
      "skiplocked" -> :skiplocked
      other -> Mix.raise("Unknown LOCK=#{inspect(other)}")
    end
  end

  defp env_int(name, default) do
    case System.get_env(name) do
      nil -> default
      value -> String.to_integer(value)
    end
  end

  defp env_bool(name, default) do
    case System.get_env(name) do
      nil -> default
      "1" -> true
      "true" -> true
      "0" -> false
      "false" -> false
      _ -> default
    end
  end

  defp cpu_approx(runtime_delta_ms, wall_us) when wall_us > 0 do
    # :erlang.statistics(:runtime) is scheduler time in ms across all schedulers.
    schedulers = :erlang.system_info(:schedulers_online)
    wall_ms = wall_us / 1000
    runtime_delta_ms / (wall_ms * schedulers) * 100
  end

  defp cpu_approx(_, _), do: 0.0

  defp write_results!(results) do
    File.mkdir_p!("benchmarks/output")
    stamp = Calendar.strftime(DateTime.utc_now(), "%Y%m%d%H%M%S")
    path = Path.join("benchmarks/output", "#{stamp}_load.json")

    payload =
      Enum.map(results, fn row ->
        row
        |> Map.drop([:report, :metrics])
        |> Map.put(:jobs_per_s, Map.get(row, :jobs_per_s))
        |> Map.put(:wall_s, (row.wall_us || 0) / 1_000_000)
        |> Map.put(:db, row.metrics.db)
        |> Map.put(:beam, row.metrics.beam)
        |> Map.put(:storage_delta_bytes, row.metrics.storage.db_delta_bytes)
      end)

    File.write!(path, Jason.encode!(payload, pretty: true))
    IO.puts("wrote #{path}")
  end
end

GoodJob.Bench.Load.run!()
