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

      # With concurrency control
      GoodJob.enqueue(MyApp.MyJob, %{data: "hello"}, concurrency_key: "user_123", concurrency_limit: 5)

      # Execute inline (synchronously)
      GoodJob.enqueue(MyApp.MyJob, %{data: "hello"}, execution_mode: :inline)
  """
  def enqueue(job_module, args, opts \\ []) do
    execution_mode = Keyword.get(opts, :execution_mode, :async)

    queue_name = Keyword.get(opts, :queue) || get_default_queue(job_module)

    priority = Keyword.get(opts, :priority) || get_default_priority(job_module)
    scheduled_at = Keyword.get(opts, :scheduled_at)
    batch_id = Keyword.get(opts, :batch_id)
    concurrency_key = Keyword.get(opts, :concurrency_key)
    tags = Keyword.get(opts, :tags, get_default_tags(job_module))

    # Check concurrency limits if configured
    concurrency_result =
      if concurrency_key do
        config = get_concurrency_config(job_module, opts)

        case GoodJob.Concurrency.check_enqueue_limit(concurrency_key, config) do
          {:ok, :ok} ->
            :ok

          {:ok, {:error, reason}} ->
            {:error, reason}

          error ->
            error
        end
      else
        :ok
      end

    case concurrency_result do
      :ok ->
        # Execute before_enqueue callback
        case GoodJob.JobCallbacks.before_enqueue(job_module, args, opts) do
          {:ok, final_args} ->
            active_job_id = Ecto.UUID.generate()

            # job_class stored in the database uses the full Elixir module
            # name (including the \"Elixir.\" prefix) so that helpers which
            # compare against to_string/1 (like GoodJob.Testing) can match
            # reliably.
            job_class_string = Atom.to_string(job_module)

            # For the serialized ActiveJob payload, use external-style class
            # naming with \"::\" separators for cross-language compatibility.
            external_job_class = GoodJob.Protocol.Serialization.module_to_external_class(job_module)

            # Serialize in ActiveJob format for cross-language compatibility
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
              concurrency_key: concurrency_key,
              labels: tags
            }

            case GoodJob.Job.enqueue(job_attrs) do
              {:ok, job} ->
                # Telemetry.enqueue is now emitted by Job.enqueue/1
                # Execute after_enqueue callback
                GoodJob.JobCallbacks.after_enqueue(job_module, job, opts)

                # Execute based on mode
                case execution_mode do
                  :inline ->
                    GoodJob.ExecutionMode.execute(job, :inline, opts)

                  :async ->
                    {:ok, job}

                  :external ->
                    GoodJob.ExecutionMode.execute(job, :external, opts)

                  _ ->
                    {:ok, job}
                end

              error ->
                error
            end

          {:error, reason} ->
            {:error, reason}
        end

      {:error, _reason} = error ->
        error
    end
  end

  defp get_default_queue(job_module) do
    if function_exported?(job_module, :__good_job_queue__, 0) do
      job_module.__good_job_queue__()
    else
      "default"
    end
  end

  defp get_default_priority(job_module) do
    if function_exported?(job_module, :__good_job_priority__, 0) do
      job_module.__good_job_priority__()
    else
      0
    end
  end

  defp get_default_tags(job_module) do
    if function_exported?(job_module, :__good_job_tags__, 0) do
      job_module.__good_job_tags__()
    else
      []
    end
  end

  defp get_concurrency_config(job_module, opts) do
    # Get concurrency config from job module or opts
    config = Keyword.get(opts, :concurrency_config, [])

    if function_exported?(job_module, :good_job_concurrency_config, 0) do
      job_module.good_job_concurrency_config()
      |> Keyword.merge(config)
    else
      config
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
    * `:include_discarded` - Whether to include discarded jobs. Default: `false`
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
