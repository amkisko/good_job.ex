defmodule GoodJob.Telemetry do
  @moduledoc """
  Telemetry events for GoodJob.

  Emits events for:
  - Job execution start/success/error/timeout/exception
  - Job lifecycle: enqueue, retry (automatic & manual), delete, cancel, discard, snooze
  - Job locking/unlocking
  - Batch operations: enqueue, complete, callback, retry
  - Concurrency limits: limit_exceeded, throttle_exceeded
  - Scheduler events: poll, job_fetched, job_not_found
  - Notifier events: listen, notified, connection_error
  - Cron events: enqueue
  - Cleanup events: preserved_jobs, triggered
  - Process tracking: heartbeat
  - Lock events: acquired, failed

  ## Default Logger

  GoodJob provides a default structured logger that you can attach:

      GoodJob.Telemetry.attach_default_logger()

  This will log all GoodJob telemetry events in a structured format.

  ## Custom Handlers

  You can attach custom telemetry handlers for specific events:

      defmodule MyApp.GoodJobLogger do
        require Logger

        def handle_event([:good_job, :job, :start], _measure, meta, _config) do
          Logger.info("Job started: \#{meta.job_class}")
        end
      end

      events = [[:good_job, :job, :start]]
      :telemetry.attach_many("my-handler", events, &MyApp.GoodJobLogger.handle_event/4, [])

  See the TELEMETRY.md file for complete documentation of all events.
  """

  alias GoodJob.Telemetry.Logger

  @doc """
  The unique id used to attach telemetry logging.

  This is the constant `"good-job-default-logger"` and exposed for testing purposes.
  """
  def default_handler_id, do: Logger.default_handler_id()

  @doc """
  Attaches a default structured Telemetry handler for logging.

  This function attaches a handler that outputs logs with structured information
  about GoodJob events.

  ## Options

  * `:level` - The log level to use for logging output, defaults to `:info`
  * `:events` - Which event categories to log. Can be `:all` or a list of categories
    like `[:job, :cron, :notifier]`. Defaults to `:all`.

  ## Examples

  Attach a logger at the default `:info` level:

      GoodJob.Telemetry.attach_default_logger()

  Attach a logger at the `:debug` level:

      GoodJob.Telemetry.attach_default_logger(level: :debug)

  Attach a logger for only job events:

      GoodJob.Telemetry.attach_default_logger(events: [:job])
  """
  def attach_default_logger(opts \\ []) do
    Logger.attach(opts)
  end

  @doc """
  Detaches the default logger handler.

  ## Examples

      GoodJob.Telemetry.attach_default_logger()
      GoodJob.Telemetry.detach_default_logger()
  """
  def detach_default_logger do
    Logger.detach()
  end

  @doc """
  Emits a telemetry event for job execution start.
  """
  def execute_start(job) do
    # Calculate queue_time (time between scheduled_at and now)
    queue_time =
      if job.scheduled_at do
        DateTime.diff(DateTime.utc_now(), job.scheduled_at, :microsecond)
        |> max(0)
      else
        0
      end

    :telemetry.execute(
      [:good_job, :job, :start],
      %{count: 1, queue_time: queue_time},
      %{
        job_id: job.id,
        active_job_id: job.active_job_id,
        job_class: job.job_class,
        queue_name: job.queue_name,
        cron_key: job.cron_key,
        queue_time: queue_time
      }
    )
  end

  @doc """
  Emits a telemetry event for successful job execution.
  """
  def execute_success(job, _result, start_time) do
    duration = System.convert_time_unit(System.monotonic_time() - start_time, :native, :microsecond)

    :telemetry.execute(
      [:good_job, :job, :success],
      %{count: 1, duration: duration},
      %{
        job_id: job.id,
        active_job_id: job.active_job_id,
        job_class: job.job_class,
        queue_name: job.queue_name,
        cron_key: job.cron_key
      }
    )
  end

  @doc """
  Emits a telemetry event for failed job execution.
  """
  def execute_error(job, error, start_time) do
    duration = System.convert_time_unit(System.monotonic_time() - start_time, :native, :microsecond)

    :telemetry.execute(
      [:good_job, :job, :error],
      %{count: 1, duration: duration},
      %{
        job_id: job.id,
        active_job_id: job.active_job_id,
        job_class: job.job_class,
        queue_name: job.queue_name,
        cron_key: job.cron_key,
        error: error
      }
    )
  end

  @doc """
  Emits a telemetry event for job enqueueing.
  """
  def enqueue(job) do
    :telemetry.execute(
      [:good_job, :job, :enqueue],
      %{count: 1},
      %{
        job_id: job.id,
        active_job_id: job.active_job_id,
        job_class: job.job_class,
        queue_name: job.queue_name
      }
    )
  end

  @doc """
  Emits a telemetry event for job retry.
  """
  def retry(job, scheduled_at) do
    :telemetry.execute(
      [:good_job, :job, :retry],
      %{count: 1},
      %{
        job_id: job.id,
        active_job_id: job.active_job_id,
        job_class: job.job_class,
        queue_name: job.queue_name,
        scheduled_at: scheduled_at
      }
    )
  end

  @doc """
  Emits a telemetry event for cron manager start.
  """
  def cron_manager_start(cron_entries) do
    :telemetry.execute(
      [:good_job, :cron_manager, :start],
      %{count: length(cron_entries)},
      %{cron_entries: cron_entries}
    )
  end

  @doc """
  Emits a telemetry event for cron job enqueueing.
  """
  def cron_job_enqueued(entry, cron_at) do
    :telemetry.execute(
      [:good_job, :cron, :enqueue],
      %{count: 1},
      %{
        cron_key: entry.key,
        cron: entry.cron,
        job_class: entry.class,
        scheduled_at: cron_at
      }
    )
  end

  @doc """
  Emits a telemetry event for job timeout.
  """
  def execute_timeout(job, timeout_ms, start_time) do
    duration = System.convert_time_unit(System.monotonic_time() - start_time, :native, :microsecond)

    :telemetry.execute(
      [:good_job, :job, :timeout],
      %{count: 1, duration: duration, timeout_ms: timeout_ms},
      %{
        job_id: job.id,
        active_job_id: job.active_job_id,
        job_class: job.job_class,
        queue_name: job.queue_name,
        timeout_ms: timeout_ms
      }
    )
  end

  @doc """
  Emits a telemetry event for notifier listen.
  """
  def notifier_listen do
    :telemetry.execute(
      [:good_job, :notifier, :listen],
      %{count: 1},
      %{}
    )
  end

  @doc """
  Emits a telemetry event for notifier notification received.
  """
  def notifier_notified(payload) do
    :telemetry.execute(
      [:good_job, :notifier, :notified],
      %{count: 1},
      %{payload: payload}
    )
  end

  @doc """
  Emits a telemetry event for cleanup operation.
  """
  def cleanup_preserved_jobs(deleted_count, opts) do
    :telemetry.execute(
      [:good_job, :cleanup, :preserved_jobs],
      %{count: deleted_count},
      %{
        older_than: Keyword.get(opts, :older_than),
        include_discarded: Keyword.get(opts, :include_discarded, false)
      }
    )
  end

  @doc """
  Emits a telemetry event for notifier connection error.
  """
  def notifier_connection_error(error_count, error) do
    :telemetry.execute(
      [:good_job, :notifier, :connection_error],
      %{count: 1, error_count: error_count},
      %{error: error}
    )
  end

  @doc """
  Emits a telemetry event for scheduler poll.
  """
  def scheduler_poll do
    :telemetry.execute(
      [:good_job, :scheduler, :poll],
      %{count: 1},
      %{}
    )
  end

  @doc """
  Emits a telemetry event for scheduler process creation.
  """
  def scheduler_process_created do
    :telemetry.execute(
      [:good_job, :scheduler, :process_created],
      %{count: 1},
      %{}
    )
  end

  @doc """
  Emits a telemetry event for cleanup trigger.
  """
  def cleanup_triggered(reason) do
    :telemetry.execute(
      [:good_job, :cleanup, :triggered],
      %{count: 1},
      %{reason: reason}
    )
  end

  @doc """
  Emits a telemetry event for process heartbeat.
  """
  def process_heartbeat(process_id) do
    :telemetry.execute(
      [:good_job, :process, :heartbeat],
      %{count: 1},
      %{process_id: process_id}
    )
  end

  @doc """
  Emits a telemetry event for job exception (detailed error information).

  This is similar to `execute_error` but includes more detailed error information
  including error kind (error, exit, throw) and stacktrace.
  """
  def execute_exception(job, error, kind, stacktrace, start_time) do
    duration = System.convert_time_unit(System.monotonic_time() - start_time, :native, :microsecond)

    :telemetry.execute(
      [:good_job, :job, :exception],
      %{count: 1, duration: duration},
      %{
        job_id: job.id,
        active_job_id: job.active_job_id,
        job_class: job.job_class,
        queue_name: job.queue_name,
        cron_key: job.cron_key,
        kind: kind,
        error: error,
        reason: error,
        stacktrace: stacktrace
      }
    )
  end

  @doc """
  Emits a telemetry event for advisory lock acquisition.
  """
  def lock_acquired(lock_key, lock_type) do
    :telemetry.execute(
      [:good_job, :lock, :acquired],
      %{count: 1},
      %{
        lock_key: lock_key,
        lock_type: lock_type
      }
    )
  end

  @doc """
  Emits a telemetry event for failed advisory lock acquisition.
  """
  def lock_failed(lock_key, lock_type) do
    :telemetry.execute(
      [:good_job, :lock, :failed],
      %{count: 1},
      %{
        lock_key: lock_key,
        lock_type: lock_type
      }
    )
  end

  # Phase 1: Critical Job Lifecycle Events

  @doc """
  Emits a telemetry event for manual job deletion.
  """
  def job_delete(job) do
    :telemetry.execute(
      [:good_job, :job, :delete],
      %{count: 1},
      %{
        job_id: job.id,
        active_job_id: job.active_job_id,
        job_class: job.job_class,
        queue_name: job.queue_name
      }
    )
  end

  @doc """
  Emits a telemetry event for manual job retry.
  """
  def job_retry_manual(job) do
    :telemetry.execute(
      [:good_job, :job, :retry_manual],
      %{count: 1},
      %{
        job_id: job.id,
        active_job_id: job.active_job_id,
        job_class: job.job_class,
        queue_name: job.queue_name
      }
    )
  end

  @doc """
  Emits a telemetry event for job cancellation.
  """
  def job_cancel(job, reason, start_time) do
    duration = System.convert_time_unit(System.monotonic_time() - start_time, :native, :microsecond)

    :telemetry.execute(
      [:good_job, :job, :cancel],
      %{count: 1, duration: duration},
      %{
        job_id: job.id,
        active_job_id: job.active_job_id,
        job_class: job.job_class,
        queue_name: job.queue_name,
        reason: reason
      }
    )
  end

  @doc """
  Emits a telemetry event for job discard.
  """
  def job_discard(job, reason, start_time) do
    duration = System.convert_time_unit(System.monotonic_time() - start_time, :native, :microsecond)

    :telemetry.execute(
      [:good_job, :job, :discard],
      %{count: 1, duration: duration},
      %{
        job_id: job.id,
        active_job_id: job.active_job_id,
        job_class: job.job_class,
        queue_name: job.queue_name,
        reason: reason
      }
    )
  end

  @doc """
  Emits a telemetry event for job snooze (reschedule).
  """
  def job_snooze(job, seconds, start_time) do
    duration = System.convert_time_unit(System.monotonic_time() - start_time, :native, :microsecond)

    :telemetry.execute(
      [:good_job, :job, :snooze],
      %{count: 1, duration: duration, seconds: seconds},
      %{
        job_id: job.id,
        active_job_id: job.active_job_id,
        job_class: job.job_class,
        queue_name: job.queue_name,
        seconds: seconds
      }
    )
  end

  # Phase 2: Batch & Concurrency Events

  @doc """
  Emits a telemetry event for batch enqueue.
  """
  def batch_enqueue(batch_record, job_count) do
    :telemetry.execute(
      [:good_job, :batch, :enqueue],
      %{count: 1, job_count: job_count},
      %{
        batch_id: batch_record.id,
        description: batch_record.description,
        job_count: job_count
      }
    )
  end

  @doc """
  Emits a telemetry event for batch completion.
  """
  def batch_complete(batch_record, discarded_count) do
    :telemetry.execute(
      [:good_job, :batch, :complete],
      %{count: 1, discarded_count: discarded_count},
      %{
        batch_id: batch_record.id,
        description: batch_record.description,
        discarded_count: discarded_count
      }
    )
  end

  @doc """
  Emits a telemetry event for batch callback execution.
  """
  def batch_callback(batch_record, event, callback_string) do
    :telemetry.execute(
      [:good_job, :batch, :callback],
      %{count: 1},
      %{
        batch_id: batch_record.id,
        event: event,
        callback: callback_string
      }
    )
  end

  @doc """
  Emits a telemetry event for batch retry.
  """
  def batch_retry(batch_record) do
    :telemetry.execute(
      [:good_job, :batch, :retry],
      %{count: 1},
      %{
        batch_id: batch_record.id,
        description: batch_record.description
      }
    )
  end

  @doc """
  Emits a telemetry event for concurrency limit exceeded.
  """
  def concurrency_limit_exceeded(concurrency_key, limit, type) do
    :telemetry.execute(
      [:good_job, :concurrency, :limit_exceeded],
      %{count: 1, limit: limit},
      %{
        concurrency_key: concurrency_key,
        limit: limit,
        type: type
      }
    )
  end

  @doc """
  Emits a telemetry event for concurrency throttle exceeded.
  """
  def concurrency_throttle_exceeded(concurrency_key, throttle, type) do
    :telemetry.execute(
      [:good_job, :concurrency, :throttle_exceeded],
      %{count: 1, throttle: throttle},
      %{
        concurrency_key: concurrency_key,
        throttle: throttle,
        type: type
      }
    )
  end

  # Phase 3: Scheduler Metrics

  @doc """
  Emits a telemetry event for job fetched from queue.
  """
  def scheduler_job_fetched(job, queue_string) do
    :telemetry.execute(
      [:good_job, :scheduler, :job_fetched],
      %{count: 1},
      %{
        job_id: job.id,
        job_class: job.job_class,
        queue_name: job.queue_name,
        queue_string: queue_string
      }
    )
  end

  @doc """
  Emits a telemetry event when no job is available.
  """
  def scheduler_job_not_found(queue_string) do
    :telemetry.execute(
      [:good_job, :scheduler, :job_not_found],
      %{count: 1},
      %{
        queue_string: queue_string
      }
    )
  end

  @doc """
  Emits a telemetry event for job locked for execution.
  """
  def job_locked(job, lock_id) do
    :telemetry.execute(
      [:good_job, :job, :locked],
      %{count: 1},
      %{
        job_id: job.id,
        job_class: job.job_class,
        queue_name: job.queue_name,
        lock_id: lock_id
      }
    )
  end

  @doc """
  Emits a telemetry event for job unlocked (stale lock cleared).
  """
  def job_unlocked(job, lock_id) do
    :telemetry.execute(
      [:good_job, :job, :unlocked],
      %{count: 1},
      %{
        job_id: job.id,
        job_class: job.job_class,
        queue_name: job.queue_name,
        lock_id: lock_id
      }
    )
  end
end
