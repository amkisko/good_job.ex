defmodule GoodJob.Protocol.ScheduledJobsTest do
  @moduledoc """
  Tests for scheduled job time semantics in Protocol integration.
  """

  use GoodJob.Test.Support.ProtocolSetup, async: false

  describe "Scheduled job time semantics" do
    test "scheduled jobs use UTC timestamps" do
      # Use a future date to ensure the job is scheduled, not queued
      scheduled_at = DateTime.add(DateTime.utc_now(), 3600, :second)

      ruby_serialized_params =
        Serialization.to_active_job(
          job_class: "MyApp::SendEmailJob",
          arguments: [%{"to" => "user@example.com"}],
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
        executions_count: 0,
        scheduled_at: scheduled_at
      }

      {:ok, job} = Job.enqueue(job_attrs)

      # Verify scheduled_at is UTC
      assert job.scheduled_at == scheduled_at
      # Verify UTC datetime (check that it's a UTC DateTime struct)
      assert %DateTime{time_zone: "Etc/UTC"} = job.scheduled_at
      # Verify job state (since scheduled_at is in the future, state should be :scheduled)
      state = Job.calculate_state(job)
      assert state == :scheduled
    end

    test "scheduled jobs become available at correct time" do
      # Schedule job 1 second in the future
      scheduled_at = DateTime.add(DateTime.utc_now(), 1, :second)

      ruby_serialized_params =
        Serialization.to_active_job(
          job_class: "MyApp::SendEmailJob",
          arguments: [%{"to" => "user@example.com"}],
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
        executions_count: 0,
        scheduled_at: scheduled_at
      }

      {:ok, job} = Job.enqueue(job_attrs)

      # Should be scheduled
      assert Job.calculate_state(job) == :scheduled

      # Wait for scheduled time
      Process.sleep(1100)

      # Should now be available
      job = Repo.repo().get!(Job, job.id)
      assert Job.calculate_state(job) == :available
    end

    test "handles timezone differences correctly" do
      # Create job with UTC timestamp
      scheduled_at_utc = ~U[2025-12-26 12:00:00.000000Z]

      ruby_serialized_params =
        Serialization.to_active_job(
          job_class: "MyApp::SendEmailJob",
          arguments: [%{"to" => "user@example.com"}],
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
        executions_count: 0,
        scheduled_at: scheduled_at_utc
      }

      {:ok, job} = Job.enqueue(job_attrs)

      # Verify UTC is preserved
      # Verify UTC datetime (check that it's a UTC DateTime struct)
      assert %DateTime{time_zone: "Etc/UTC"} = job.scheduled_at
      assert job.scheduled_at == scheduled_at_utc
    end
  end
end
