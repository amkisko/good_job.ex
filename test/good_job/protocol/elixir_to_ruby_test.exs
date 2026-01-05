defmodule GoodJob.Protocol.ElixirToRubyTest do
  @moduledoc """
  Tests for Elixir → Ruby job execution (simulated) in Protocol integration.
  """

  use GoodJob.Test.Support.ProtocolSetup, async: false

  alias GoodJob.Protocol.TestJobs

  describe "Elixir → Ruby job execution (simulated)" do
    test "enqueues job from Elixir format for Ruby processing" do
      # Enqueue job using Protocol helper (as Elixir would)
      {:ok, job} =
        Protocol.enqueue_for_external(
          "MyApp::ProcessPaymentJob",
          %{"user_id" => 123, "amount" => 100.00},
          queue: "default"
        )

      # Verify job is in Ruby-compatible format
      assert job.job_class == "MyApp::ProcessPaymentJob"
      assert job.queue_name == "default"
      assert is_map(job.serialized_params)
      assert job.serialized_params["job_class"] == "MyApp::ProcessPaymentJob"
      assert is_list(job.serialized_params["arguments"])

      # Verify ActiveJob format
      {:ok, job_class, arguments, executions, _metadata} =
        Serialization.from_active_job(job.serialized_params)

      assert job_class == "MyApp::ProcessPaymentJob"
      assert executions == 0
      assert not Enum.empty?(arguments)
    end

    test "converts Elixir module name to external class format" do
      # Enqueue using Elixir module name
      {:ok, job} =
        Protocol.enqueue_for_external(
          TestJobs.PaymentJob,
          %{"user_id" => 123},
          queue: "default"
        )

      # Should be converted to Ruby format
      assert job.job_class == "TestJobs.PaymentJob" || String.contains?(job.job_class, "::")
      assert job.serialized_params["job_class"] == job.job_class
    end
  end
end
