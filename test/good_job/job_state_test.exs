defmodule GoodJob.JobStateTest do
  use ExUnit.Case, async: true

  alias GoodJob.JobState

  describe "all/0" do
    test "returns all valid states" do
      states = JobState.all()

      assert :available in states
      assert :executing in states
      assert :completed in states
      assert :discarded in states
      assert :cancelled in states
      assert :retryable in states
      assert length(states) == 6
    end
  end

  describe "valid?/1" do
    test "returns true for valid states" do
      assert JobState.valid?(:available) == true
      assert JobState.valid?(:executing) == true
      assert JobState.valid?(:completed) == true
      assert JobState.valid?(:discarded) == true
      assert JobState.valid?(:cancelled) == true
      assert JobState.valid?(:retryable) == true
    end

    test "returns false for invalid states" do
      assert JobState.valid?(:invalid) == false
      assert JobState.valid?(:pending) == false
      assert JobState.valid?("available") == false
    end
  end

  describe "transition/2" do
    test "transitions to completed on :ok" do
      assert JobState.transition(:available, :ok) == :completed
      assert JobState.transition(:executing, :ok) == :completed
    end

    test "transitions to completed on {:ok, value}" do
      assert JobState.transition(:available, {:ok, "result"}) == :completed
    end

    test "transitions to cancelled on {:cancel, reason}" do
      assert JobState.transition(:executing, {:cancel, "cancelled"}) == :cancelled
    end

    test "transitions to discarded on :discard" do
      assert JobState.transition(:executing, :discard) == :discarded
    end

    test "transitions to discarded on {:discard, reason}" do
      assert JobState.transition(:executing, {:discard, "discarded"}) == :discarded
    end

    test "transitions to retryable on {:error, reason}" do
      assert JobState.transition(:executing, {:error, "failed"}) == :retryable
    end

    test "transitions to available on {:snooze, seconds}" do
      assert JobState.transition(:executing, {:snooze, 60}) == :available
    end

    test "keeps current state on unknown result" do
      assert JobState.transition(:available, :unknown) == :available
      assert JobState.transition(:executing, 123) == :executing
    end
  end

  describe "can_transition?/2" do
    test "allows valid transitions" do
      assert JobState.can_transition?(:available, :executing) == true
      assert JobState.can_transition?(:executing, :completed) == true
      assert JobState.can_transition?(:executing, :retryable) == true
      assert JobState.can_transition?(:executing, :cancelled) == true
      assert JobState.can_transition?(:executing, :discarded) == true
      assert JobState.can_transition?(:retryable, :available) == true
      assert JobState.can_transition?(:retryable, :discarded) == true
    end

    test "disallows invalid transitions" do
      assert JobState.can_transition?(:available, :completed) == false
      assert JobState.can_transition?(:completed, :executing) == false
      assert JobState.can_transition?(:discarded, :available) == false
      assert JobState.can_transition?(:cancelled, :executing) == false
    end
  end

  describe "final?/1" do
    test "returns true for final states" do
      assert JobState.final?(:completed) == true
      assert JobState.final?(:discarded) == true
      assert JobState.final?(:cancelled) == true
    end

    test "returns false for non-final states" do
      assert JobState.final?(:available) == false
      assert JobState.final?(:executing) == false
      assert JobState.final?(:retryable) == false
    end
  end

  describe "to_string/1" do
    test "converts state atom to string" do
      assert JobState.to_string(:available) == "available"
      assert JobState.to_string(:executing) == "executing"
      assert JobState.to_string(:completed) == "completed"
    end
  end

  describe "from_string/1" do
    test "converts valid string to state atom" do
      assert JobState.from_string("available") == :available
      assert JobState.from_string("executing") == :executing
      assert JobState.from_string("completed") == :completed
    end

    test "returns nil for invalid string" do
      assert JobState.from_string("invalid") == nil
      assert JobState.from_string("pending") == nil
    end

    test "returns nil for non-existent atom" do
      assert JobState.from_string("nonexistent_state") == nil
    end
  end
end
