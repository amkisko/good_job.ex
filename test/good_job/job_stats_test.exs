defmodule GoodJob.JobStatsTest do
  use ExUnit.Case, async: false
  use GoodJob.Testing.JobCase

  alias GoodJob.{Job, JobStats, Repo}

  describe "stats/0" do
    test "returns statistics for all queues" do
      repo = Repo.repo()

      repo.transaction(fn ->
        # Create jobs in different states
        {:ok, queued_job} = GoodJob.enqueue(TestJob, %{data: "queued"})
        {:ok, _running_job} = GoodJob.enqueue(TestJob, %{data: "running"})

        # Mark one as running (performed but not finished)
        now = DateTime.utc_now()

        queued_job
        |> Job.changeset(%{performed_at: now})
        |> repo.update!()

        stats = JobStats.stats()

        assert is_map(stats)
        assert Map.has_key?(stats, :total)
        assert Map.has_key?(stats, :queued)
        assert Map.has_key?(stats, :running)
        assert Map.has_key?(stats, :succeeded)
        assert Map.has_key?(stats, :discarded)
        assert Map.has_key?(stats, :with_errors)
        assert Map.has_key?(stats, :oldest_job)
        assert Map.has_key?(stats, :newest_job)
        assert stats.total >= 2
        assert stats.queued >= 1
        assert stats.running >= 1
      end)
    end

    test "returns zero counts when no jobs exist" do
      repo = Repo.repo()

      repo.transaction(fn ->
        stats = JobStats.stats()

        assert stats.total == 0
        assert stats.queued == 0
        assert stats.running == 0
        assert stats.succeeded == 0
        assert stats.discarded == 0
        assert stats.with_errors == 0
        assert stats.oldest_job == nil
        assert stats.newest_job == nil
      end)
    end
  end

  describe "stats/1" do
    test "returns statistics for specific queue" do
      repo = Repo.repo()

      repo.transaction(fn ->
        # Create jobs in different queues
        GoodJob.enqueue(TestJob, %{data: "test1"}, queue: "queue1")
        GoodJob.enqueue(TestJob, %{data: "test2"}, queue: "queue1")
        GoodJob.enqueue(TestJob, %{data: "test3"}, queue: "queue2")

        stats = JobStats.stats("queue1")

        assert is_map(stats)
        assert stats.total == 2
        assert stats.queued == 2
      end)
    end

    test "returns zero counts for non-existent queue" do
      repo = Repo.repo()

      repo.transaction(fn ->
        stats = JobStats.stats("nonexistent_queue")

        assert stats.total == 0
        assert stats.queued == 0
      end)
    end
  end

  describe "count_queued/1" do
    test "delegates to Counters.count_queued" do
      repo = Repo.repo()

      repo.transaction(fn ->
        GoodJob.enqueue(TestJob, %{data: "test"})

        count = JobStats.count_queued(Job)
        assert is_integer(count)
        assert count >= 1
      end)
    end
  end

  describe "count_running/1" do
    test "delegates to Counters.count_running" do
      repo = Repo.repo()

      repo.transaction(fn ->
        {:ok, job} = GoodJob.enqueue(TestJob, %{data: "test"})

        # Mark as running
        now = DateTime.utc_now()

        job
        |> Job.changeset(%{performed_at: now})
        |> repo.update!()

        count = JobStats.count_running(Job)
        assert is_integer(count)
        assert count >= 1
      end)
    end
  end

  describe "count_succeeded/1" do
    test "delegates to Counters.count_succeeded" do
      repo = Repo.repo()

      repo.transaction(fn ->
        {:ok, job} = GoodJob.enqueue(TestJob, %{data: "test"})

        # Mark as succeeded
        now = DateTime.utc_now()

        job
        |> Job.changeset(%{
          performed_at: DateTime.add(now, -1, :second),
          finished_at: now
        })
        |> repo.update!()

        count = JobStats.count_succeeded(Job)
        assert is_integer(count)
        assert count >= 1
      end)
    end
  end

  describe "count_discarded/1" do
    test "delegates to Counters.count_discarded" do
      repo = Repo.repo()

      repo.transaction(fn ->
        {:ok, job} = GoodJob.enqueue(TestJob, %{data: "test"})

        # Mark as discarded
        now = DateTime.utc_now()

        job
        |> Job.changeset(%{
          performed_at: DateTime.add(now, -1, :second),
          finished_at: now,
          error: "Test error"
        })
        |> repo.update!()

        count = JobStats.count_discarded(Job)
        assert is_integer(count)
        assert count >= 1
      end)
    end
  end

  describe "count_all/1" do
    test "delegates to Counters.count_all" do
      repo = Repo.repo()

      repo.transaction(fn ->
        GoodJob.enqueue(TestJob, %{data: "test1"})
        GoodJob.enqueue(TestJob, %{data: "test2"})

        count = JobStats.count_all(Job)
        assert is_integer(count)
        assert count >= 2
      end)
    end
  end

  describe "count_with_errors/1" do
    test "delegates to Counters.count_with_errors" do
      repo = Repo.repo()

      repo.transaction(fn ->
        {:ok, job} = GoodJob.enqueue(TestJob, %{data: "test"})

        # Add error
        job
        |> Job.changeset(%{error: "Test error"})
        |> repo.update!()

        count = JobStats.count_with_errors(Job)
        assert is_integer(count)
        assert count >= 1
      end)
    end
  end

  describe "oldest_job/1" do
    test "delegates to Counters.oldest_job" do
      repo = Repo.repo()

      repo.transaction(fn ->
        {:ok, job1} = GoodJob.enqueue(TestJob, %{data: "test1"})
        Process.sleep(10)
        {:ok, _job2} = GoodJob.enqueue(TestJob, %{data: "test2"})

        oldest = JobStats.oldest_job(Job)
        assert oldest != nil
        assert oldest.id == job1.id
      end)
    end

    test "returns nil when no jobs exist" do
      repo = Repo.repo()

      repo.transaction(fn ->
        oldest = JobStats.oldest_job(Job)
        assert oldest == nil
      end)
    end
  end

  describe "newest_job/1" do
    test "delegates to Counters.newest_job" do
      repo = Repo.repo()

      repo.transaction(fn ->
        {:ok, _job1} = GoodJob.enqueue(TestJob, %{data: "test1"})
        Process.sleep(10)
        {:ok, job2} = GoodJob.enqueue(TestJob, %{data: "test2"})

        newest = JobStats.newest_job(Job)
        assert newest != nil
        assert newest.id == job2.id
      end)
    end

    test "returns nil when no jobs exist" do
      repo = Repo.repo()

      repo.transaction(fn ->
        newest = JobStats.newest_job(Job)
        assert newest == nil
      end)
    end
  end

  describe "queue_stats/0" do
    test "delegates to Aggregation.queue_stats" do
      repo = Repo.repo()

      repo.transaction(fn ->
        GoodJob.enqueue(TestJob, %{data: "test1"}, queue: "queue1")
        GoodJob.enqueue(TestJob, %{data: "test2"}, queue: "queue2")

        stats = JobStats.queue_stats()
        assert is_map(stats)
      end)
    end
  end

  describe "job_class_stats/0" do
    test "delegates to Aggregation.job_class_stats" do
      repo = Repo.repo()

      repo.transaction(fn ->
        GoodJob.enqueue(TestJob, %{data: "test"})

        stats = JobStats.job_class_stats()
        assert is_map(stats)
      end)
    end
  end

  describe "average_execution_time/0" do
    test "returns average execution time for all queues" do
      repo = Repo.repo()

      repo.transaction(fn ->
        {:ok, job} = GoodJob.enqueue(TestJob, %{data: "test"})

        # Simulate job completion with execution time
        now = DateTime.utc_now()
        performed_at = DateTime.add(now, -5, :second)

        job
        |> Job.changeset(%{
          performed_at: performed_at,
          finished_at: now
        })
        |> repo.update!()

        avg_time = JobStats.average_execution_time()
        # Should return a float or nil
        assert avg_time == nil or is_float(avg_time)
      end)
    end

    test "returns nil when no completed jobs" do
      repo = Repo.repo()

      repo.transaction(fn ->
        avg_time = JobStats.average_execution_time()
        assert avg_time == nil
      end)
    end
  end

  describe "average_execution_time/1" do
    test "returns average execution time for specific queue" do
      repo = Repo.repo()

      repo.transaction(fn ->
        {:ok, job} = GoodJob.enqueue(TestJob, %{data: "test"}, queue: "queue1")

        # Simulate job completion
        now = DateTime.utc_now()
        performed_at = DateTime.add(now, -3, :second)

        job
        |> Job.changeset(%{
          performed_at: performed_at,
          finished_at: now
        })
        |> repo.update!()

        avg_time = JobStats.average_execution_time("queue1")
        assert avg_time == nil or is_float(avg_time)
      end)
    end

    test "returns nil for queue with no completed jobs" do
      repo = Repo.repo()

      repo.transaction(fn ->
        GoodJob.enqueue(TestJob, %{data: "test"}, queue: "queue1")

        avg_time = JobStats.average_execution_time("queue1")
        assert avg_time == nil
      end)
    end
  end

  describe "activity_over_time/1" do
    test "delegates to TimeSeries.activity_over_time" do
      repo = Repo.repo()

      repo.transaction(fn ->
        GoodJob.enqueue(TestJob, %{data: "test"})

        result = JobStats.activity_over_time(24)
        assert is_map(result)
        assert Map.has_key?(result, :labels)
        assert Map.has_key?(result, :created)
        assert Map.has_key?(result, :completed)
        assert Map.has_key?(result, :failed)
      end)
    end
  end
end
