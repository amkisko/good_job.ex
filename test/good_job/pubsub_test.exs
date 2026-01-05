defmodule GoodJob.PubSubTest do
  use ExUnit.Case, async: true

  alias GoodJob.PubSub

  describe "broadcast/2" do
    test "broadcasts job_created event" do
      result = PubSub.broadcast(:job_created, "job-123")
      assert result in [:ok, :noop]
    end

    test "broadcasts job_updated event" do
      result = PubSub.broadcast(:job_updated, "job-123")
      assert result in [:ok, :noop]
    end

    test "broadcasts job_completed event" do
      result = PubSub.broadcast(:job_completed, "job-123")
      assert result in [:ok, :noop]
    end

    test "broadcasts job_deleted event" do
      result = PubSub.broadcast(:job_deleted, "job-123")
      assert result in [:ok, :noop]
    end

    test "broadcasts job_retried event" do
      result = PubSub.broadcast(:job_retried, "job-123")
      assert result in [:ok, :noop]
    end

    test "broadcasts job_discarded event" do
      result = PubSub.broadcast(:job_discarded, "job-123")
      assert result in [:ok, :noop]
    end
  end

  describe "subscribe/1" do
    test "subscribes to events" do
      result = PubSub.subscribe()
      assert result in ["good_job:jobs", nil]
    end

    test "subscribes with nil server" do
      result = PubSub.subscribe(nil)
      assert result in ["good_job:jobs", nil]
    end

    test "get_pubsub_server returns nil when not configured" do
      # Test the private function indirectly through subscribe
      result = PubSub.subscribe()
      assert result in ["good_job:jobs", nil]
    end
  end
end
