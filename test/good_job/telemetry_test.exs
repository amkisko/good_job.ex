defmodule GoodJob.TelemetryTest do
  use ExUnit.Case, async: true

  alias GoodJob.Telemetry

  test "attach and detach default logger" do
    assert :ok == Telemetry.attach_default_logger()
    assert :ok == Telemetry.detach_default_logger()
  end

  test "emits concurrency and notifier telemetry events" do
    Telemetry.concurrency_limit_exceeded("key-1", 1, :perform)
    Telemetry.concurrency_throttle_exceeded("key-2", {1, 10}, :enqueue)
    Telemetry.notifier_listen()
    Telemetry.notifier_notified(%{"queue_name" => "default"})
  end
end
