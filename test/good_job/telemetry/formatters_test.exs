defmodule GoodJob.Telemetry.FormattersTest do
  use ExUnit.Case, async: true

  alias GoodJob.Telemetry.Formatters

  test "build_job_log_message formats job lifecycle events" do
    base_meta = %{job_class: "MyJob", job_id: "1234567890abcdef", queue_name: "default"}

    assert Formatters.build_job_log_message(:start, %{}, base_meta) =~ "Job started"
    assert Formatters.build_job_log_message(:enqueue, %{}, base_meta) =~ "Job enqueued"

    success =
      Formatters.build_job_log_message(:success, %{duration: 2_000}, base_meta)

    assert success =~ "Job completed"

    error =
      Formatters.build_job_log_message(:error, %{duration: 1_000}, Map.put(base_meta, :error, "boom"))

    assert error =~ "Job failed"

    timeout =
      Formatters.build_job_log_message(:timeout, %{duration: 1_000}, Map.put(base_meta, :timeout_ms, 500))

    assert timeout =~ "Job timeout"

    retry_meta = Map.put(base_meta, :scheduled_at, DateTime.utc_now())
    retry = Formatters.build_job_log_message(:retry, %{}, retry_meta)
    assert retry =~ "Job retry scheduled"
  end

  test "build_generic_log_message formats known categories and fallback" do
    assert Formatters.build_generic_log_message(:cron, :enqueue, %{}, %{cron: "0 * * * *", cron_key: "key"}) =~
             "Cron job enqueued"

    assert Formatters.build_generic_log_message(:notifier, :listen, %{}, %{}) =~ "Notifier started listening"
    assert Formatters.build_generic_log_message(:notifier, :notified, %{}, %{}) =~ "Notifier received"
    assert Formatters.build_generic_log_message(:scheduler, :poll, %{}, %{}) =~ "Scheduler polling"

    assert Formatters.build_generic_log_message(:custom, :event, %{}, %{}) == "[GoodJob] custom.event"
  end
end
