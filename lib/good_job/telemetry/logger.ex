defmodule GoodJob.Telemetry.Logger do
  @moduledoc """
  Default logger handler for GoodJob telemetry events.
  """

  require Logger

  @default_handler_id "good-job-default-logger"
  @all_event_categories [:job, :batch, :concurrency, :lock, :cron, :notifier, :scheduler, :cleanup, :process]

  @doc """
  The unique id used to attach telemetry logging.
  """
  def default_handler_id, do: @default_handler_id

  @doc """
  Attaches a default structured Telemetry handler for logging.
  """
  def attach(opts \\ []) do
    level = Keyword.get(opts, :level, :info)
    events_filter = Keyword.get(opts, :events, :all)

    events =
      case events_filter do
        :all ->
          build_events_from_filter(@all_event_categories)

        filter when is_list(filter) ->
          build_events_from_filter(filter)
      end

    :telemetry.attach_many(@default_handler_id, events, &handle_event/4, %{level: level})
  end

  @doc """
  Detaches the default logger handler.
  """
  def detach do
    :telemetry.detach(@default_handler_id)
  end

  @doc false
  def handle_event([:good_job, :job, event], measure, meta, %{level: level}) do
    log_message = GoodJob.Telemetry.Formatters.build_job_log_message(event, measure, meta)
    Logger.log(level, log_message)
  end

  def handle_event([:good_job, category, event], measure, meta, %{level: level}) do
    log_message = GoodJob.Telemetry.Formatters.build_generic_log_message(category, event, measure, meta)
    Logger.log(level, log_message)
  end

  defp build_events_from_filter(filter) do
    event_map = %{
      job: [
        [:good_job, :job, :start],
        [:good_job, :job, :success],
        [:good_job, :job, :error],
        [:good_job, :job, :exception],
        [:good_job, :job, :timeout],
        [:good_job, :job, :enqueue],
        [:good_job, :job, :retry],
        [:good_job, :job, :retry_manual],
        [:good_job, :job, :delete],
        [:good_job, :job, :cancel],
        [:good_job, :job, :discard],
        [:good_job, :job, :snooze],
        [:good_job, :job, :locked],
        [:good_job, :job, :unlocked]
      ],
      batch: [
        [:good_job, :batch, :enqueue],
        [:good_job, :batch, :complete],
        [:good_job, :batch, :callback],
        [:good_job, :batch, :retry]
      ],
      concurrency: [
        [:good_job, :concurrency, :limit_exceeded],
        [:good_job, :concurrency, :throttle_exceeded]
      ],
      lock: [
        [:good_job, :lock, :acquired],
        [:good_job, :lock, :failed]
      ],
      cron: [
        [:good_job, :cron, :enqueue],
        [:good_job, :cron_manager, :start]
      ],
      notifier: [
        [:good_job, :notifier, :listen],
        [:good_job, :notifier, :notified],
        [:good_job, :notifier, :connection_error]
      ],
      scheduler: [
        [:good_job, :scheduler, :poll],
        [:good_job, :scheduler, :process_created],
        [:good_job, :scheduler, :job_fetched],
        [:good_job, :scheduler, :job_not_found]
      ],
      cleanup: [
        [:good_job, :cleanup, :preserved_jobs],
        [:good_job, :cleanup, :triggered]
      ],
      process: [
        [:good_job, :process, :heartbeat]
      ]
    }

    filter
    |> Enum.flat_map(fn category ->
      Map.get(event_map, category, [])
    end)
  end
end
