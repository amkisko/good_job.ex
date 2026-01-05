defmodule GoodJob.JobStats.TimeSeriesTest do
  use ExUnit.Case, async: false
  use GoodJob.Testing.JobCase

  alias GoodJob.{Job, JobStats.TimeSeries, Repo}

  describe "activity_over_time/1" do
    test "returns activity data for last 24 hours" do
      repo = Repo.repo()

      repo.transaction(fn ->
        # Create a test job
        GoodJob.enqueue(TestJob, %{data: "test"})

        result = TimeSeries.activity_over_time(24)
        assert is_map(result)
        assert Map.has_key?(result, :labels)
        assert Map.has_key?(result, :created)
        assert Map.has_key?(result, :completed)
        assert Map.has_key?(result, :failed)
        assert is_list(result.labels)
        assert is_list(result.created)
        assert is_list(result.completed)
        assert is_list(result.failed)
        # All arrays should have the same length
        assert length(result.labels) == length(result.created)
        assert length(result.created) == length(result.completed)
        assert length(result.completed) == length(result.failed)
      end)
    end

    test "returns activity data for custom hours" do
      repo = Repo.repo()

      repo.transaction(fn ->
        result = TimeSeries.activity_over_time(12)
        assert is_map(result)
        # For 12 hours, we get 13 labels (hour 0 through hour 12 inclusive)
        assert length(result.labels) <= 13
        assert length(result.labels) == length(result.created)
      end)
    end

    test "includes created jobs in created array" do
      repo = Repo.repo()

      repo.transaction(fn ->
        # Create multiple jobs
        GoodJob.enqueue(TestJob, %{data: "test1"})
        GoodJob.enqueue(TestJob, %{data: "test2"})
        GoodJob.enqueue(TestJob, %{data: "test3"})

        result = TimeSeries.activity_over_time(24)
        # Should have at least some created jobs
        total_created = Enum.sum(result.created)
        assert total_created >= 3
      end)
    end

    test "includes completed jobs in completed array" do
      repo = Repo.repo()

      repo.transaction(fn ->
        # Create and complete jobs
        {:ok, job1} = GoodJob.enqueue(TestJob, %{data: "test1"})
        {:ok, job2} = GoodJob.enqueue(TestJob, %{data: "test2"})

        # Mark jobs as completed
        now = DateTime.utc_now()
        performed_at = DateTime.add(now, -1, :second)

        job1
        |> Job.changeset(%{
          performed_at: performed_at,
          finished_at: now
        })
        |> repo.update!()

        job2
        |> Job.changeset(%{
          performed_at: performed_at,
          finished_at: now
        })
        |> repo.update!()

        result = TimeSeries.activity_over_time(24)
        # Should have at least some completed jobs
        total_completed = Enum.sum(result.completed)
        assert total_completed >= 2
      end)
    end

    test "includes failed jobs in failed array" do
      repo = Repo.repo()

      repo.transaction(fn ->
        # Create and fail jobs
        {:ok, job1} = GoodJob.enqueue(TestJob, %{data: "test1"})
        {:ok, job2} = GoodJob.enqueue(TestJob, %{data: "test2"})

        # Mark jobs as failed
        now = DateTime.utc_now()
        performed_at = DateTime.add(now, -1, :second)

        job1
        |> Job.changeset(%{
          performed_at: performed_at,
          finished_at: now,
          error: "Test error 1"
        })
        |> repo.update!()

        job2
        |> Job.changeset(%{
          performed_at: performed_at,
          finished_at: now,
          error: "Test error 2"
        })
        |> repo.update!()

        result = TimeSeries.activity_over_time(24)
        # Should have at least some failed jobs
        total_failed = Enum.sum(result.failed)
        assert total_failed >= 2
      end)
    end

    test "handles jobs across multiple hours" do
      repo = Repo.repo()

      repo.transaction(fn ->
        # Create jobs at different times
        GoodJob.enqueue(TestJob, %{data: "test1"})

        # Wait a bit to ensure different timestamps
        Process.sleep(100)
        GoodJob.enqueue(TestJob, %{data: "test2"})

        result = TimeSeries.activity_over_time(24)
        # Should have labels for multiple hours
        assert result.labels != []
        # All arrays should match in length
        assert length(result.labels) == length(result.created)
      end)
    end

    test "returns empty arrays when no jobs exist" do
      repo = Repo.repo()

      repo.transaction(fn ->
        result = TimeSeries.activity_over_time(24)
        # Should still return proper structure
        assert is_map(result)
        assert Map.has_key?(result, :labels)
        assert Map.has_key?(result, :created)
        assert Map.has_key?(result, :completed)
        assert Map.has_key?(result, :failed)
        # Labels should exist even if no jobs
        assert is_list(result.labels)
        assert result.labels != []
      end)
    end

    test "handles default hours parameter" do
      repo = Repo.repo()

      repo.transaction(fn ->
        # Test default parameter (24 hours)
        result = TimeSeries.activity_over_time()
        assert is_map(result)
        assert result.labels != []
      end)
    end

    test "handles very small hour ranges" do
      repo = Repo.repo()

      repo.transaction(fn ->
        # Test with 1 hour
        result = TimeSeries.activity_over_time(1)
        assert is_map(result)
        # Current hour and possibly next
        assert length(result.labels) <= 2
        assert length(result.labels) == length(result.created)
      end)
    end

    test "handles large hour ranges" do
      repo = Repo.repo()

      repo.transaction(fn ->
        # Test with 48 hours
        result = TimeSeries.activity_over_time(48)
        assert is_map(result)
        # 48 hours + 1
        assert length(result.labels) <= 49
        assert length(result.labels) == length(result.created)
      end)
    end

    test "returns consistent data structure" do
      repo = Repo.repo()

      repo.transaction(fn ->
        GoodJob.enqueue(TestJob, %{data: "test"})

        result = TimeSeries.activity_over_time(24)

        # Verify all keys exist
        assert Map.has_key?(result, :labels)
        assert Map.has_key?(result, :created)
        assert Map.has_key?(result, :completed)
        assert Map.has_key?(result, :failed)

        # Verify all values are lists
        assert is_list(result.labels)
        assert is_list(result.created)
        assert is_list(result.completed)
        assert is_list(result.failed)

        # Verify all lists have same length
        assert length(result.labels) == length(result.created)
        assert length(result.created) == length(result.completed)
        assert length(result.completed) == length(result.failed)

        # Verify labels are strings
        assert Enum.all?(result.labels, &is_binary/1)

        # Verify counts are integers
        assert Enum.all?(result.created, &is_integer/1)
        assert Enum.all?(result.completed, &is_integer/1)
        assert Enum.all?(result.failed, &is_integer/1)
      end)
    end
  end
end
