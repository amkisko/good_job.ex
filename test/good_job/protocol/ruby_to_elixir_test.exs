defmodule GoodJob.Protocol.RubyToElixirTest do
  @moduledoc """
  Tests for Ruby → Elixir job execution in Protocol integration.
  """

  use GoodJob.Test.Support.ProtocolSetup, async: false

  describe "Ruby → Elixir job execution" do
    test "enqueues job from Ruby format and executes in Elixir" do
      # Simulate Ruby GoodJob enqueueing a job
      # Ruby format: ActiveJob serialization with "job_class" as string
      ruby_serialized_params =
        Serialization.to_active_job(
          job_class: "MyApp::SendEmailJob",
          arguments: [%{"to" => "user@example.com", "subject" => "Hello"}],
          queue_name: "default",
          priority: 0,
          executions: 0
        )

      active_job_id = Ecto.UUID.generate()

      job_attrs = %{
        active_job_id: active_job_id,
        job_class: "MyApp::SendEmailJob",
        queue_name: "default",
        priority: 0,
        serialized_params: ruby_serialized_params,
        executions_count: 0
      }

      # Enqueue job (as Ruby would)
      {:ok, job} = Job.enqueue(job_attrs)

      # Verify job is in correct format
      assert job.job_class == "MyApp::SendEmailJob"
      assert job.queue_name == "default"
      assert is_map(job.serialized_params)
      assert job.serialized_params["job_class"] == "MyApp::SendEmailJob"
      assert job.serialized_params["arguments"] == [%{"to" => "user@example.com", "subject" => "Hello"}]
      assert job.serialized_params["executions"] == 0

      # Execute job (as Elixir would) - use execute_inline to set performed_at
      JobExecutor.execute_inline(job)

      # Verify job was executed
      job = Repo.repo().get!(Job, job.id)
      assert not is_nil(job.performed_at)
      assert not is_nil(job.finished_at)
      assert is_nil(job.error)

      # Verify executions count updated in both places
      assert job.executions_count == 1
      assert job.serialized_params["executions"] == 1
    end

    test "handles Ruby job class name format (:: separator)" do
      # Ruby uses "MyApp::MyJob" format
      ruby_serialized_params =
        Serialization.to_active_job(
          job_class: "MyApp::ProcessPaymentJob",
          arguments: [%{"user_id" => 123, "amount" => 100.00}],
          queue_name: "default",
          priority: 0,
          executions: 0
        )

      active_job_id = Ecto.UUID.generate()

      job_attrs = %{
        active_job_id: active_job_id,
        job_class: "MyApp::ProcessPaymentJob",
        queue_name: "default",
        priority: 0,
        serialized_params: ruby_serialized_params,
        executions_count: 0
      }

      {:ok, job} = Job.enqueue(job_attrs)

      # Execute job - should resolve via Handler Registry
      lock_id = GoodJob.ProcessTracker.id_for_lock()
      {:ok, _result} = JobExecutor.execute(job, lock_id)

      # Verify execution
      job = Repo.repo().get!(Job, job.id)
      assert not is_nil(job.finished_at)
      assert is_nil(job.error)
    end

    test "updates executions count in serialized_params on retry" do
      # Create a job that will fail and retry
      ruby_serialized_params =
        Serialization.to_active_job(
          job_class: "MyApp::SendEmailJob",
          arguments: [%{"to" => "user@example.com", "subject" => "Hello", "fail" => true}],
          queue_name: "default",
          priority: 0,
          executions: 0
        )

      active_job_id = Ecto.UUID.generate()

      job_attrs = %{
        active_job_id: active_job_id,
        job_class: "MyApp::SendEmailJob",
        queue_name: "default",
        priority: 0,
        serialized_params: ruby_serialized_params,
        executions_count: 0
      }

      {:ok, job} = Job.enqueue(job_attrs)

      # Execute job (will fail) - use execute_inline for testing
      JobExecutor.execute_inline(job)

      # Verify executions count updated in both places
      job = Repo.repo().get!(Job, job.id)
      assert job.executions_count == 1
      assert job.serialized_params["executions"] == 1
    end
  end
end
