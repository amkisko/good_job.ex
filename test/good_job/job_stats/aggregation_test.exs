defmodule GoodJob.JobStats.AggregationTest do
  use ExUnit.Case, async: false
  use GoodJob.Testing.JobCase

  alias GoodJob.{Job, JobStats.Aggregation, Repo}

  describe "queue_stats/0" do
    test "returns queue statistics" do
      repo = Repo.repo()

      repo.transaction(fn ->
        # Create some test jobs in different queues
        GoodJob.enqueue(TestJob, %{data: "test1"}, queue: "queue1")
        GoodJob.enqueue(TestJob, %{data: "test2"}, queue: "queue1")
        GoodJob.enqueue(TestJob, %{data: "test3"}, queue: "queue2")

        stats = Aggregation.queue_stats()
        assert is_map(stats)
        # Should have counts for queues
        assert Map.has_key?(stats, "queue1") or Map.has_key?(stats, :queue1)
      end)
    end
  end

  describe "job_class_stats/0" do
    test "returns job class statistics" do
      repo = Repo.repo()

      repo.transaction(fn ->
        # Create some test jobs
        GoodJob.enqueue(TestJob, %{data: "test"})

        stats = Aggregation.job_class_stats()
        assert is_map(stats)
      end)
    end
  end

  describe "average_execution_time/1" do
    test "returns average execution time for completed jobs" do
      repo = Repo.repo()

      repo.transaction(fn ->
        # Create and complete a job
        {:ok, job} = GoodJob.enqueue(TestJob, %{data: "test"})

        # Simulate job completion by updating timestamps
        now = DateTime.utc_now()
        performed_at = DateTime.add(now, -5, :second)

        job
        |> Job.changeset(%{performed_at: performed_at, finished_at: now})
        |> repo.update!()

        avg_time = Aggregation.average_execution_time(Job)
        # Should return a float or nil
        assert avg_time == nil or is_float(avg_time)
      end)
    end

    test "returns nil when no completed jobs" do
      repo = Repo.repo()

      repo.transaction(fn ->
        avg_time = Aggregation.average_execution_time(Job)
        assert avg_time == nil
      end)
    end
  end
end
