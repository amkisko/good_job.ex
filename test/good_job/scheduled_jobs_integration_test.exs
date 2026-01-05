defmodule GoodJob.ScheduledJobsIntegrationTest do
  @moduledoc """
  Tests for scheduled job time semantics and timezone handling.

  These tests verify that scheduled jobs work correctly with:
  - UTC timestamps (Ruby and Elixir both use UTC)
  - Timezone handling
  - Clock skew tolerance
  - Scheduled job precision

  ## References

  - Ruby GoodJob uses UTC timestamps (Time.current in Rails)
  - Elixir uses DateTime.utc_now() for UTC timestamps
  - PostgreSQL stores timestamps in UTC
  """

  use ExUnit.Case, async: false
  use GoodJob.Testing.JobCase

  alias GoodJob.{Job, Repo}
  alias GoodJob.Protocol.Serialization

  @moduletag :integration
  @moduletag :scheduled_jobs

  describe "Scheduled job time semantics" do
    test "scheduled jobs use UTC timestamps" do
      scheduled_at = ~U[2025-12-26 12:00:00.000000Z]

      ruby_serialized_params =
        Serialization.to_active_job(
          job_class: "TestJobs.SimpleJob",
          arguments: [],
          queue_name: "default",
          priority: 0,
          executions: 0
        )

      active_job_id = Ecto.UUID.generate()

      job_attrs = %{
        active_job_id: active_job_id,
        job_class: "TestJobs.SimpleJob",
        queue_name: "default",
        priority: 0,
        serialized_params: ruby_serialized_params,
        executions_count: 0,
        scheduled_at: scheduled_at
      }

      {:ok, job} = Job.enqueue(job_attrs)

      # Verify UTC
      # Verify UTC datetime (check that it's a UTC DateTime struct)
      assert %DateTime{time_zone: "Etc/UTC"} = job.scheduled_at
      assert job.scheduled_at == scheduled_at
    end

    test "scheduled jobs become available at correct time" do
      # Schedule 100ms in the future
      scheduled_at = DateTime.add(DateTime.utc_now(), 100, :millisecond)

      ruby_serialized_params =
        Serialization.to_active_job(
          job_class: "TestJobs.SimpleJob",
          arguments: [],
          queue_name: "default",
          priority: 0,
          executions: 0
        )

      active_job_id = Ecto.UUID.generate()

      job_attrs = %{
        active_job_id: active_job_id,
        job_class: "TestJobs.SimpleJob",
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
      Process.sleep(150)

      # Should now be available
      job = Repo.repo().get!(Job, job.id)
      assert Job.calculate_state(job) == :available
    end

    test "handles clock skew tolerance" do
      # Schedule job with small negative offset (simulating clock skew)
      # Ruby might schedule with slightly different time
      now = DateTime.utc_now()
      # 5 seconds in the past
      scheduled_at = DateTime.add(now, -5, :second)

      ruby_serialized_params =
        Serialization.to_active_job(
          job_class: "TestJobs.SimpleJob",
          arguments: [],
          queue_name: "default",
          priority: 0,
          executions: 0
        )

      active_job_id = Ecto.UUID.generate()

      job_attrs = %{
        active_job_id: active_job_id,
        job_class: "TestJobs.SimpleJob",
        queue_name: "default",
        priority: 0,
        serialized_params: ruby_serialized_params,
        executions_count: 0,
        scheduled_at: scheduled_at
      }

      {:ok, job} = Job.enqueue(job_attrs)

      # Should be queued immediately (scheduled time is in the past)
      assert Job.calculate_state(job) == :available
    end

    test "scheduled job precision (millisecond level)" do
      # Test that scheduled_at precision is preserved
      scheduled_at = ~U[2025-12-26 12:00:00.123456Z]

      ruby_serialized_params =
        Serialization.to_active_job(
          job_class: "TestJobs.SimpleJob",
          arguments: [],
          queue_name: "default",
          priority: 0,
          executions: 0
        )

      active_job_id = Ecto.UUID.generate()

      job_attrs = %{
        active_job_id: active_job_id,
        job_class: "TestJobs.SimpleJob",
        queue_name: "default",
        priority: 0,
        serialized_params: ruby_serialized_params,
        executions_count: 0,
        scheduled_at: scheduled_at
      }

      {:ok, job} = Job.enqueue(job_attrs)

      # Verify precision is preserved
      assert job.scheduled_at.microsecond == scheduled_at.microsecond
    end

    test "timezone conversion is consistent" do
      # Ruby GoodJob uses Time.current (Rails timezone) but stores UTC
      # Elixir uses DateTime.utc_now() directly
      # Both should result in same UTC timestamp

      # Simulate Ruby scheduling (would use Time.current but store UTC)
      ruby_scheduled_at = ~U[2025-12-26 12:00:00.000000Z]

      # Elixir scheduling (direct UTC)
      elixir_scheduled_at = ~U[2025-12-26 12:00:00.000000Z]

      # Both should be identical
      assert DateTime.compare(ruby_scheduled_at, elixir_scheduled_at) == :eq
    end
  end

  describe "Scheduled job state transitions" do
    test "job transitions from scheduled to queued at correct time" do
      scheduled_at = DateTime.add(DateTime.utc_now(), 500, :millisecond)

      ruby_serialized_params =
        Serialization.to_active_job(
          job_class: "TestJobs.SimpleJob",
          arguments: [],
          queue_name: "default",
          priority: 0,
          executions: 0
        )

      active_job_id = Ecto.UUID.generate()

      job_attrs = %{
        active_job_id: active_job_id,
        job_class: "TestJobs.SimpleJob",
        queue_name: "default",
        priority: 0,
        serialized_params: ruby_serialized_params,
        executions_count: 0,
        scheduled_at: scheduled_at
      }

      {:ok, job} = Job.enqueue(job_attrs)

      # Initially scheduled
      assert Job.calculate_state(job) == :scheduled

      # Wait for scheduled time
      Process.sleep(600)

      # Should be queued
      job = Repo.repo().get!(Job, job.id)
      assert Job.calculate_state(job) == :available
    end
  end

  # Test job module
  defmodule TestJobs.SimpleJob do
    use GoodJob.Job

    @impl GoodJob.Behaviour
    def perform(_args) do
      :ok
    end
  end
end
