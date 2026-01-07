defmodule GoodJob.Telemetry.Formatters do
  @moduledoc """
  Formatters for telemetry log messages.
  """

  alias GoodJob.Utils

  @doc """
  Builds a log message for job events.
  """
  def build_job_log_message(:start, _measure, meta) do
    "[GoodJob] Job started: #{meta.job_class} (id: #{String.slice(meta.job_id, 0..8)}...) " <>
      "queue: #{meta.queue_name}"
  end

  def build_job_log_message(:success, measure, meta) do
    duration_ms = div(measure.duration, 1000)

    "[GoodJob] Job completed: #{meta.job_class} in #{duration_ms}ms " <>
      "(id: #{String.slice(meta.job_id, 0..8)}...) queue: #{meta.queue_name}"
  end

  def build_job_log_message(:error, measure, meta) do
    duration_ms = div(measure.duration, 1000)
    error = Utils.format_error(meta.error)

    "[GoodJob] Job failed: #{meta.job_class} in #{duration_ms}ms " <>
      "(id: #{String.slice(meta.job_id, 0..8)}...) queue: #{meta.queue_name} " <>
      "error: #{error}"
  end

  def build_job_log_message(:timeout, measure, meta) do
    duration_ms = div(measure.duration, 1000)

    "[GoodJob] Job timeout: #{meta.job_class} in #{duration_ms}ms " <>
      "(id: #{String.slice(meta.job_id, 0..8)}...) queue: #{meta.queue_name} " <>
      "timeout: #{meta.timeout_ms}ms"
  end

  def build_job_log_message(:enqueue, _measure, meta) do
    "[GoodJob] Job enqueued: #{meta.job_class} " <>
      "(id: #{String.slice(meta.job_id, 0..8)}...) queue: #{meta.queue_name}"
  end

  def build_job_log_message(:retry, _measure, meta) do
    scheduled_at = Utils.format_datetime_log(meta.scheduled_at)

    "[GoodJob] Job retry scheduled: #{meta.job_class} " <>
      "(id: #{String.slice(meta.job_id, 0..8)}...) queue: #{meta.queue_name} " <>
      "scheduled_at: #{scheduled_at}"
  end

  @doc """
  Builds a log message for generic events.
  """
  def build_generic_log_message(:cron, :enqueue, _measure, meta) do
    job_class = Map.get(meta, :job_class, "unknown")
    cron = Map.get(meta, :cron, "unknown")
    cron_key = Map.get(meta, :cron_key, "unknown")

    "[GoodJob] Cron job enqueued: #{job_class} " <>
      "(cron: #{cron}, key: #{cron_key})"
  end

  def build_generic_log_message(:notifier, :listen, _measure, _meta) do
    "[GoodJob] Notifier started listening"
  end

  def build_generic_log_message(:notifier, :notified, _measure, _meta) do
    "[GoodJob] Notifier received notification"
  end

  def build_generic_log_message(:scheduler, :poll, _measure, _meta) do
    "[GoodJob] Scheduler polling for jobs"
  end

  def build_generic_log_message(category, event, _measure, _meta) do
    "[GoodJob] #{category}.#{event}"
  end
end
