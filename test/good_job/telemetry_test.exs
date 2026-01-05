defmodule GoodJob.TelemetryTest do
  use ExUnit.Case, async: true

  alias GoodJob.Telemetry

  describe "default_handler_id/0" do
    test "returns handler id" do
      assert Telemetry.default_handler_id() == "good-job-default-logger"
    end
  end

  describe "attach_default_logger/1" do
    test "attaches logger with default options" do
      Telemetry.attach_default_logger()
      # Verify it doesn't crash
      assert true
      Telemetry.detach_default_logger()
    end

    test "attaches logger with custom level" do
      Telemetry.attach_default_logger(level: :debug)
      assert true
      Telemetry.detach_default_logger()
    end

    test "attaches logger with event filter" do
      Telemetry.attach_default_logger(events: [:job])
      assert true
      Telemetry.detach_default_logger()
    end

    test "attaches logger with all events" do
      Telemetry.attach_default_logger(events: :all)
      assert true
      Telemetry.detach_default_logger()
    end
  end

  describe "detach_default_logger/0" do
    test "detaches logger" do
      Telemetry.attach_default_logger()
      Telemetry.detach_default_logger()
      # Verify it doesn't crash
      assert true
    end
  end

  describe "event execution" do
    alias GoodJob.Job

    setup do
      job = %Job{
        id: Ecto.UUID.generate(),
        job_class: "TestJob",
        queue_name: "default",
        active_job_id: Ecto.UUID.generate()
      }

      {:ok, job: job}
    end

    test "executes job_start event", %{job: job} do
      Telemetry.attach_default_logger(level: :debug)
      Telemetry.execute_start(job)
      Telemetry.detach_default_logger()
    end

    test "executes job_success event", %{job: job} do
      Telemetry.attach_default_logger(level: :debug)
      start_time = System.monotonic_time()
      Telemetry.execute_success(job, :ok, start_time)
      Telemetry.detach_default_logger()
    end

    test "executes job_error event", %{job: job} do
      Telemetry.attach_default_logger(level: :debug)
      start_time = System.monotonic_time()
      Telemetry.execute_error(job, %RuntimeError{message: "error"}, start_time)
      Telemetry.detach_default_logger()
    end

    test "executes job_exception event", %{job: job} do
      # Don't attach logger for exception as it uses different handler
      start_time = System.monotonic_time()
      Telemetry.execute_exception(job, %RuntimeError{message: "error"}, :error, [], start_time)
      assert true
    end

    test "executes job_timeout event", %{job: job} do
      Telemetry.attach_default_logger(level: :debug)
      start_time = System.monotonic_time()
      Telemetry.execute_timeout(job, 5000, start_time)
      Telemetry.detach_default_logger()
    end

    test "executes job_enqueue event", %{job: job} do
      Telemetry.attach_default_logger(level: :debug)
      Telemetry.enqueue(job)
      Telemetry.detach_default_logger()
    end

    test "executes job_retry event", %{job: job} do
      Telemetry.attach_default_logger(level: :debug)
      scheduled_at = DateTime.utc_now()
      Telemetry.retry(job, scheduled_at)
      Telemetry.detach_default_logger()
    end

    test "executes lock_acquired event" do
      Telemetry.attach_default_logger(level: :debug)
      Telemetry.lock_acquired(12_345, :xact)
      Telemetry.detach_default_logger()
    end

    test "executes lock_failed event" do
      Telemetry.attach_default_logger(level: :debug)
      Telemetry.lock_failed(12_345, :xact)
      Telemetry.detach_default_logger()
    end

    test "executes cron_enqueue event" do
      Telemetry.attach_default_logger(level: :debug)
      entry = %{key: "test", class: "TestJob", cron: "*/1 * * * *"}
      cron_at = DateTime.utc_now()
      Telemetry.cron_job_enqueued(entry, cron_at)
      Telemetry.detach_default_logger()
    end

    test "executes process_heartbeat event" do
      Telemetry.attach_default_logger(level: :debug)
      Telemetry.process_heartbeat("process-123")
      Telemetry.detach_default_logger()
    end

    test "executes scheduler_poll event" do
      Telemetry.attach_default_logger(level: :debug)
      Telemetry.scheduler_poll()
      Telemetry.detach_default_logger()
    end

    test "executes notifier_listen event" do
      Telemetry.attach_default_logger(level: :debug)
      Telemetry.notifier_listen()
      Telemetry.detach_default_logger()
    end

    test "executes notifier_notified event" do
      Telemetry.attach_default_logger(level: :debug)
      Telemetry.notifier_notified("payload")
      Telemetry.detach_default_logger()
    end
  end
end
