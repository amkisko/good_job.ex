defmodule GoodJob.Bench.Metrics do
  @moduledoc false

  def sample(repo) do
    %{
      wall_ms: System.monotonic_time(:millisecond),
      beam: beam_sample(),
      db: db_sample(repo),
      storage: storage_sample(repo)
    }
  end

  def diff(before, after_sample) do
    wall_ms = after_sample.wall_ms - before.wall_ms

    %{
      wall_ms: wall_ms,
      wall_s: wall_ms / 1000,
      beam: %{
        reductions: after_sample.beam.reductions - before.beam.reductions,
        runtime_ms: after_sample.beam.runtime_ms - before.beam.runtime_ms,
        memory_total_bytes: after_sample.beam.memory_total_bytes,
        memory_delta_bytes: after_sample.beam.memory_total_bytes - before.beam.memory_total_bytes,
        process_count: after_sample.beam.process_count,
        process_delta: after_sample.beam.process_count - before.beam.process_count
      },
      db: %{
        xact_commit: after_sample.db.xact_commit - before.db.xact_commit,
        xact_rollback: after_sample.db.xact_rollback - before.db.xact_rollback,
        blks_read: after_sample.db.blks_read - before.db.blks_read,
        blks_hit: after_sample.db.blks_hit - before.db.blks_hit,
        tup_returned: after_sample.db.tup_returned - before.db.tup_returned,
        tup_fetched: after_sample.db.tup_fetched - before.db.tup_fetched,
        tup_inserted: after_sample.db.tup_inserted - before.db.tup_inserted,
        tup_updated: after_sample.db.tup_updated - before.db.tup_updated,
        tup_deleted: after_sample.db.tup_deleted - before.db.tup_deleted,
        temp_files: after_sample.db.temp_files - before.db.temp_files,
        temp_bytes: after_sample.db.temp_bytes - before.db.temp_bytes,
        deadlocks: after_sample.db.deadlocks - before.db.deadlocks,
        cache_hit_ratio: cache_hit_ratio(after_sample.db, before.db)
      },
      storage: %{
        db_bytes: after_sample.storage.db_bytes,
        db_delta_bytes: after_sample.storage.db_bytes - before.storage.db_bytes,
        good_jobs_bytes: after_sample.storage.good_jobs_bytes,
        good_jobs_delta_bytes: after_sample.storage.good_jobs_bytes - before.storage.good_jobs_bytes,
        executions_bytes: after_sample.storage.executions_bytes,
        executions_delta_bytes:
          after_sample.storage.executions_bytes - before.storage.executions_bytes,
        wal_bytes: wal_bytes_delta(before.storage.wal_lsn, after_sample.storage.wal_lsn)
      },
      queries: Map.get(after_sample, :queries, 0) - Map.get(before, :queries, 0)
    }
  end

  def attach_query_counter do
    handler_id = "good-job-bench-ecto-#{System.unique_integer([:positive])}"
    prefix = Application.get_env(:good_job, GoodJob.TestRepo)[:telemetry_prefix] || [:good_job, :test_repo]

    :telemetry.attach(
      handler_id,
      prefix ++ [:query],
      fn _event, _measurements, _meta, _config ->
        :persistent_term.put({__MODULE__, :query_count}, query_count() + 1)
      end,
      nil
    )

    :persistent_term.put({__MODULE__, :query_count}, 0)
    handler_id
  end

  def query_count do
    :persistent_term.get({__MODULE__, :query_count}, 0)
  end

  def reset_query_count do
    :persistent_term.put({__MODULE__, :query_count}, 0)
  end

  def with_query_count(fun) when is_function(fun, 0) do
    before = query_count()
    result = fun.()
    {result, query_count() - before}
  end

  defp beam_sample do
    memory = :erlang.memory()
    {runtime_ms, _} = :erlang.statistics(:runtime)
    {reductions, _} = :erlang.statistics(:reductions)

    %{
      reductions: reductions,
      runtime_ms: runtime_ms,
      memory_total_bytes: Keyword.get(memory, :total, 0),
      process_count: :erlang.system_info(:process_count)
    }
  end

  defp db_sample(repo) do
    %{rows: [row]} =
      Ecto.Adapters.SQL.query!(
        repo,
        """
        SELECT
          xact_commit, xact_rollback, blks_read, blks_hit,
          tup_returned, tup_fetched, tup_inserted, tup_updated, tup_deleted,
          temp_files, temp_bytes, deadlocks
        FROM pg_stat_database
        WHERE datname = current_database()
        """,
        []
      )

    [
      xact_commit,
      xact_rollback,
      blks_read,
      blks_hit,
      tup_returned,
      tup_fetched,
      tup_inserted,
      tup_updated,
      tup_deleted,
      temp_files,
      temp_bytes,
      deadlocks
    ] = row

    %{
      xact_commit: xact_commit,
      xact_rollback: xact_rollback,
      blks_read: blks_read,
      blks_hit: blks_hit,
      tup_returned: tup_returned,
      tup_fetched: tup_fetched,
      tup_inserted: tup_inserted,
      tup_updated: tup_updated,
      tup_deleted: tup_deleted,
      temp_files: temp_files,
      temp_bytes: temp_bytes,
      deadlocks: deadlocks
    }
  end

  defp storage_sample(repo) do
    %{rows: [[db_bytes]]} =
      Ecto.Adapters.SQL.query!(repo, "SELECT pg_database_size(current_database())", [])

    %{rows: [[good_jobs_bytes]]} =
      Ecto.Adapters.SQL.query!(repo, "SELECT pg_total_relation_size('good_jobs')", [])

    %{rows: [[executions_bytes]]} =
      Ecto.Adapters.SQL.query!(
        repo,
        "SELECT pg_total_relation_size('good_job_executions')",
        []
      )

    %{rows: [[wal_lsn]]} =
      Ecto.Adapters.SQL.query!(repo, "SELECT pg_current_wal_lsn()::text", [])

    %{
      db_bytes: db_bytes,
      good_jobs_bytes: good_jobs_bytes,
      executions_bytes: executions_bytes,
      wal_lsn: wal_lsn
    }
  end

  defp cache_hit_ratio(after_db, before_db) do
    hits = after_db.blks_hit - before_db.blks_hit
    reads = after_db.blks_read - before_db.blks_read
    total = hits + reads

    if total == 0 do
      1.0
    else
      hits / total
    end
  end

  defp wal_bytes_delta(before_lsn, after_lsn) do
    # pg_wal_lsn_diff needs SQL; approximate via string compare fallback 0
    # Caller should prefer SQL-based delta when possible.
    {before_lsn, after_lsn}
  end

  def wal_bytes_between(repo, before_lsn, after_lsn)
      when is_binary(before_lsn) and is_binary(after_lsn) do
    # Pass as text so Postgrex does not try to bind pg_lsn as int8.
    %{rows: [[bytes]]} =
      Ecto.Adapters.SQL.query!(
        repo,
        "SELECT pg_wal_lsn_diff($1::text::pg_lsn, $2::text::pg_lsn)",
        [after_lsn, before_lsn]
      )

    bytes
  end

  def format_report(label, jobs, metrics, extras \\ %{}) do
    jobs_per_s =
      if metrics.wall_s > 0 do
        Float.round(jobs / metrics.wall_s, 1)
      else
        0.0
      end

    queries = Map.get(extras, :queries, metrics[:queries])
    wal_bytes = to_int(Map.get(extras, :wal_bytes, 0))
    cpu_pct = Map.get(extras, :cpu_pct)

    [
      "",
      "=== #{label} ===",
      "jobs=#{jobs} wall_s=#{Float.round(metrics.wall_s, 3)} jobs/s=#{jobs_per_s}",
      "beam reductions=#{metrics.beam.reductions} runtime_ms=#{metrics.beam.runtime_ms} mem_delta_kb=#{div(to_int(metrics.beam.memory_delta_bytes), 1024)} processes=#{metrics.beam.process_count} (Δ#{metrics.beam.process_delta})",
      "db xact_commit=#{metrics.db.xact_commit} tup_ins=#{metrics.db.tup_inserted} tup_upd=#{metrics.db.tup_updated} tup_fetch=#{metrics.db.tup_fetched} tup_ret=#{metrics.db.tup_returned} blks_read=#{metrics.db.blks_read} cache_hit=#{Float.round(metrics.db.cache_hit_ratio * 100, 2)}%",
      "storage db_delta_kb=#{div(to_int(metrics.storage.db_delta_bytes), 1024)} jobs_rel_delta_kb=#{div(to_int(metrics.storage.good_jobs_delta_bytes), 1024)} exec_rel_delta_kb=#{div(to_int(metrics.storage.executions_delta_bytes), 1024)} wal_kb=#{div(wal_bytes, 1024)}",
      "network_proxy queries=#{queries || "n/a"} (ecto round-trips) db_blocks=#{metrics.db.blks_read + metrics.db.blks_hit}",
      if(cpu_pct, do: "cpu_approx_pct=#{Float.round(cpu_pct * 1.0, 1)}", else: nil)
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n")
  end

  defp to_int(%Decimal{} = value), do: Decimal.to_integer(value)
  defp to_int(value) when is_integer(value), do: value
  defp to_int(value) when is_float(value), do: round(value)
  defp to_int(value) when is_binary(value), do: String.to_integer(value)
  defp to_int(_), do: 0
end
