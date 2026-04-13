defmodule GoodJob do
  @moduledoc """
  GoodJob is a concurrent, Postgres-based job queue backend for Elixir.

  GoodJob provides a complete job queue system with:
  - PostgreSQL backend with advisory locks
  - LISTEN/NOTIFY for low-latency job dispatch
  - Cron-like scheduled jobs
  - Batch job support
  - Concurrency controls
  - Retry mechanisms

  ## Configuration

      config :good_job,
        repo: MyApp.Repo,
        queues: "*",
        max_processes: 5,
        poll_interval: 10

  ## Usage

      # Define a job
      defmodule MyApp.MyJob do
        use GoodJob.Job

        def perform(%{data: data}) do
          # Your job logic
        end
      end

      # Enqueue a job
      MyApp.MyJob.enqueue(%{data: "hello"})
  """

  @doc """
  Returns the current configuration.
  """
  defdelegate config, to: GoodJob.Config

  @doc """
  Enqueues a job for execution.

  ## Examples

      GoodJob.enqueue(MyApp.MyJob, %{data: "hello"})

      GoodJob.enqueue(MyApp.MyJob, %{data: "hello"}, queue: "high_priority", priority: 1)

      # With concurrency control (limits from module or opts; see :concurrency_config)
      GoodJob.enqueue(MyApp.MyJob, %{data: "hello"}, concurrency_key: "user_123", concurrency_config: [total_limit: 5])

      # Execute inline (synchronously)
      GoodJob.enqueue(MyApp.MyJob, %{data: "hello"}, execution_mode: :inline)

      # Bulk enqueue (single NOTIFY): used by `GoodJob.Batch.enqueue_all/1`
      GoodJob.enqueue(MyApp.MyJob, %{data: "hello"}, batch_id: batch_id, listen_notify: false)
  """
  def enqueue(job_module, args, opts \\ []) do
    case prepare_enqueue(job_module, args, opts) do
      {:ok, prepared} -> commit_enqueue(prepared)
      {:error, _} = err -> err
    end
  end

  @doc false
  def prepare_enqueue(job_module, args, opts \\ []) do
    execution_mode = Keyword.get(opts, :execution_mode, :async)

    {callback_module, job_class_string, external_job_class} = normalize_job_identifier(job_module)

    queue_name = Keyword.get(opts, :queue) || get_default_queue(callback_module)

    priority = Keyword.get(opts, :priority) || get_default_priority(callback_module)
    scheduled_at = Keyword.get(opts, :scheduled_at)
    batch_id = Keyword.get(opts, :batch_id)
    batch_callback_id = Keyword.get(opts, :batch_callback_id)
    concurrency_key = Keyword.get(opts, :concurrency_key)
    tags = Keyword.get(opts, :tags, get_default_tags(callback_module))

    concurrency_result =
      if concurrency_key do
        config = get_concurrency_config(job_module, opts)
        enqueue_concurrency_with_retry(concurrency_key, config, 5)
      else
        :ok
      end

    case concurrency_result do
      :ok ->
        case before_enqueue(callback_module, args, opts) do
          {:ok, final_args} ->
            active_job_id = Ecto.UUID.generate()

            serialized_params =
              GoodJob.Protocol.Serialization.to_active_job(
                job_class: external_job_class,
                arguments: final_args,
                queue_name: queue_name,
                priority: priority,
                executions: 0,
                job_id: active_job_id,
                concurrency_key: concurrency_key,
                labels: tags
              )

            job_attrs = %{
              active_job_id: active_job_id,
              job_class: job_class_string,
              queue_name: queue_name,
              priority: priority,
              serialized_params: serialized_params,
              scheduled_at: scheduled_at,
              executions_count: 0,
              batch_id: batch_id,
              batch_callback_id: batch_callback_id,
              concurrency_key: concurrency_key,
              labels: tags
            }

            {:ok,
             %{
               job_attrs: job_attrs,
               callback_module: callback_module,
               opts: opts,
               execution_mode: execution_mode
             }}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, _} = error ->
        error
    end
  end

  @doc false
  def commit_enqueue(%{
        job_attrs: job_attrs,
        callback_module: callback_module,
        opts: opts,
        execution_mode: execution_mode
      }) do
    listen_notify? = Keyword.get(opts, :listen_notify, true)

    if execution_mode != :inline and GoodJob.Bulk.buffering?() do
      GoodJob.Bulk.add(%{
        job_attrs: job_attrs,
        callback_module: callback_module,
        opts: opts
      })
    else
      case GoodJob.Job.enqueue(job_attrs, listen_notify: listen_notify?) do
        {:ok, job} ->
          after_enqueue(callback_module, job, opts)
          GoodJob.ExecutionMode.execute(job, execution_mode, opts)

        error ->
          error
      end
    end
  end

  defp get_default_queue(job_module) do
    if is_atom(job_module) and function_exported?(job_module, :__good_job_queue__, 0) do
      job_module.__good_job_queue__()
    else
      "default"
    end
  end

  defp get_default_priority(job_module) do
    if is_atom(job_module) and function_exported?(job_module, :__good_job_priority__, 0) do
      job_module.__good_job_priority__()
    else
      0
    end
  end

  defp get_default_tags(job_module) do
    if is_atom(job_module) and function_exported?(job_module, :__good_job_tags__, 0) do
      job_module.__good_job_tags__()
    else
      []
    end
  end

  defp get_concurrency_config(job_module, opts) do
    # Get concurrency config from job module or opts
    config = Keyword.get(opts, :concurrency_config, [])

    if is_atom(job_module) and function_exported?(job_module, :good_job_concurrency_config, 0) do
      job_module.good_job_concurrency_config()
      |> Keyword.merge(config)
    else
      config
    end
  end

  defp normalize_job_identifier(job_module) when is_atom(job_module) do
    job_class_string = Atom.to_string(job_module)
    external_job_class = GoodJob.Protocol.Serialization.module_to_external_class(job_module)
    {job_module, job_class_string, external_job_class}
  end

  defp normalize_job_identifier(job_class_string) when is_binary(job_class_string) do
    callback_module = Map.get(GoodJob.Config.external_jobs(), job_class_string)
    {callback_module, job_class_string, job_class_string}
  end

  defp before_enqueue(nil, args, _opts), do: {:ok, args}
  defp before_enqueue(job_module, args, opts), do: GoodJob.JobCallbacks.before_enqueue(job_module, args, opts)

  defp after_enqueue(nil, _job, _opts), do: :ok
  defp after_enqueue(job_module, job, opts), do: GoodJob.JobCallbacks.after_enqueue(job_module, job, opts)

  defp enqueue_concurrency_with_retry(concurrency_key, config, attempts) do
    case GoodJob.Concurrency.check_enqueue_limit(concurrency_key, config) do
      {:ok, :ok} ->
        :ok

      # Ecto `Repo.transaction/1` (arity 0) wraps callback returns as `{:ok, value}` at the DB
      # layer, so `lock_failed` from `Concurrency` comes back as `{:ok, {:error, :lock_failed}}` —
      # not top-level `{:error, :lock_failed}`. Handle those before generic limit errors.
      {:ok, {:error, :lock_failed}} when attempts > 1 ->
        Process.sleep(10)
        enqueue_concurrency_with_retry(concurrency_key, config, attempts - 1)

      {:ok, {:error, :lock_failed}} ->
        {:error, :lock_failed}

      {:ok, {:error, reason}} ->
        {:error, reason}

      {:error, :lock_failed} when attempts > 1 ->
        Process.sleep(10)
        enqueue_concurrency_with_retry(concurrency_key, config, attempts - 1)

      {:error, :lock_failed} ->
        {:error, :lock_failed}

      other ->
        other
    end
  end

  @doc """
  Shuts down all GoodJob processes gracefully.

  ## Options

    * `:timeout` - Timeout in milliseconds to wait for shutdown. Default: `-1` (wait forever)
  """
  def shutdown(opts \\ []) do
    timeout = Keyword.get(opts, :timeout, -1)
    GoodJob.Supervisor.shutdown(timeout: timeout)
  end

  @doc """
  Checks if GoodJob is shut down.
  """
  def shutdown? do
    GoodJob.Supervisor.shutdown?()
  end

  @doc """
  Cleans up preserved job records older than the specified time.

  ## Options

    * `:older_than` - Jobs older than this (in seconds) will be deleted. Default: 14 days
    * `:include_discarded` - Whether to include discarded jobs. Default: config `cleanup_discarded_jobs` (`true`)
    * `:max_count` - Maximum number of preserved jobs/executions to keep. Default: config `cleanup_preserved_jobs_max_count` (`nil`)
  """
  def cleanup_preserved_jobs(opts \\ []) do
    GoodJob.Cleanup.cleanup_preserved_jobs(opts)
  end

  @doc """
  Pauses job execution for a given queue or job class.

  ## Options

    * `:queue` - Queue name to pause
    * `:job_class` - Job class name to pause
  """
  def pause(opts \\ []) do
    GoodJob.SettingManager.pause(opts)
  end

  @doc """
  Unpauses job execution for a given queue or job class.

  ## Options

    * `:queue` - Queue name to unpause
    * `:job_class` - Job class name to unpause
  """
  def unpause(opts \\ []) do
    GoodJob.SettingManager.unpause(opts)
  end

  @doc """
  Checks if job execution is paused for a given queue or job class.

  ## Options

    * `:queue` - Queue name to check
    * `:job_class` - Job class name to check
  """
  def paused?(opts \\ []) do
    GoodJob.SettingManager.paused?(opts)
  end

  @doc """
  Creates a new batch for grouping jobs together.
  """
  defdelegate new_batch(opts \\ []), to: GoodJob.Batch, as: :new

  @doc """
  Returns job statistics for all queues.
  """
  @spec stats() :: map()
  def stats do
    GoodJob.JobStats.stats()
  end

  @doc """
  Returns job statistics for a specific queue.
  """
  @spec stats(String.t()) :: map()
  def stats(queue_name) when is_binary(queue_name) do
    GoodJob.JobStats.stats(queue_name)
  end
end
