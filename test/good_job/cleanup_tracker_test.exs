defmodule GoodJob.CleanupTrackerTest do
  use ExUnit.Case, async: true

  alias GoodJob.CleanupTracker

  describe "new/1" do
    test "creates tracker with defaults" do
      tracker = CleanupTracker.new()
      assert tracker.cleanup_interval_seconds == false
      assert tracker.cleanup_interval_jobs == false
      assert tracker.job_count == 0
      assert is_struct(tracker.last_at, DateTime)
    end

    test "creates tracker with options" do
      tracker =
        CleanupTracker.new(
          cleanup_interval_seconds: 600,
          cleanup_interval_jobs: 1000
        )

      assert tracker.cleanup_interval_seconds == 600
      assert tracker.cleanup_interval_jobs == 1000
    end

    test "raises for zero intervals" do
      assert_raise ArgumentError, fn ->
        CleanupTracker.new(cleanup_interval_seconds: 0)
      end
    end
  end

  describe "increment/1" do
    test "increments job count" do
      tracker = CleanupTracker.new()
      tracker = CleanupTracker.increment(tracker)
      assert tracker.job_count == 1
    end

    test "increments multiple times" do
      tracker = CleanupTracker.new()
      tracker = tracker |> CleanupTracker.increment() |> CleanupTracker.increment()
      assert tracker.job_count == 2
    end
  end

  describe "cleanup?/1" do
    test "returns false when thresholds not met" do
      tracker =
        CleanupTracker.new(
          cleanup_interval_seconds: 600,
          cleanup_interval_jobs: 1000
        )

      assert CleanupTracker.cleanup?(tracker) == false
    end

    test "returns true when job count threshold met" do
      tracker = CleanupTracker.new(cleanup_interval_jobs: 5)
      tracker = Enum.reduce(1..5, tracker, fn _, acc -> CleanupTracker.increment(acc) end)
      assert CleanupTracker.cleanup?(tracker) == true
    end

    test "returns true when interval is -1" do
      tracker = CleanupTracker.new(cleanup_interval_jobs: -1)
      assert CleanupTracker.cleanup?(tracker) == true
    end

    test "returns true when time threshold met" do
      past = DateTime.add(DateTime.utc_now(), -700, :second)

      tracker = %CleanupTracker{
        cleanup_interval_seconds: 600,
        cleanup_interval_jobs: false,
        job_count: 0,
        last_at: past
      }

      assert CleanupTracker.cleanup?(tracker) == true
    end
  end

  describe "reset/1" do
    test "resets counters" do
      tracker = CleanupTracker.new()
      tracker = Enum.reduce(1..5, tracker, fn _, acc -> CleanupTracker.increment(acc) end)
      tracker = CleanupTracker.reset(tracker)
      assert tracker.job_count == 0
      assert not is_nil(tracker.last_at)
    end
  end
end
