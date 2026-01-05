defmodule GoodJob.Protocol.RetrySemanticsTest do
  @moduledoc """
  Tests for retry semantics in Protocol integration.
  """

  use GoodJob.Test.Support.ProtocolSetup, async: false

  describe "Retry semantics" do
    test "Ruby job retries correctly when executed by Elixir" do
      # Create a job that will fail
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

      # Verify retry state
      job = Repo.repo().get!(Job, job.id)
      assert job.executions_count == 1
      assert job.serialized_params["executions"] == 1
      assert not is_nil(job.error)
      # Not finished yet (will retry)
      assert is_nil(job.finished_at)
      # Scheduled for retry
      assert not is_nil(job.scheduled_at)

      # Verify serialized_params updated correctly
      {:ok, _job_class, _arguments, executions, _metadata} =
        Serialization.from_active_job(job.serialized_params)

      assert executions == 1
    end

    test "executions count increments correctly across retries" do
      ruby_serialized_params =
        Serialization.to_active_job(
          job_class: "MyApp::SendEmailJob",
          arguments: [%{"to" => "user@example.com", "fail" => true}],
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

      # First execution (fails) - use execute_inline for testing
      JobExecutor.execute_inline(job)

      job = Repo.repo().get!(Job, job.id)
      assert job.executions_count == 1
      assert job.serialized_params["executions"] == 1

      # Simulate retry (clear scheduled_at to make it available)
      job
      |> Job.changeset(%{scheduled_at: nil})
      |> Repo.repo().update!()

      # Second execution (fails again) - use execute_inline for testing
      JobExecutor.execute_inline(job)

      job = Repo.repo().get!(Job, job.id)
      assert job.executions_count == 2
      assert job.serialized_params["executions"] == 2
    end
  end
end
