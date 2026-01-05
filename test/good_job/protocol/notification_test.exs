defmodule GoodJob.Protocol.NotificationTest do
  use ExUnit.Case, async: true

  alias GoodJob.Protocol.Notification

  describe "for_job/1" do
    test "creates notification with queue_name only when scheduled_at is nil" do
      job = %GoodJob.Job{
        queue_name: "default",
        scheduled_at: nil
      }

      notification = Notification.for_job(job)

      assert notification == %{"queue_name" => "default"}
      assert Map.has_key?(notification, "queue_name")
      refute Map.has_key?(notification, "scheduled_at")
    end

    test "creates notification with queue_name and scheduled_at when scheduled_at is present" do
      scheduled_at = ~U[2026-01-15 10:30:45.123456Z]

      job = %GoodJob.Job{
        queue_name: "high_priority",
        scheduled_at: scheduled_at
      }

      notification = Notification.for_job(job)

      assert Map.has_key?(notification, "queue_name")
      assert Map.has_key?(notification, "scheduled_at")
      assert notification["queue_name"] == "high_priority"
      assert notification["scheduled_at"] == "2026-01-15T10:30:45.123456Z"
    end

    test "formats scheduled_at as ISO8601 string" do
      # Test various DateTime formats
      test_cases = [
        {~U[2026-01-15 10:30:00Z], "2026-01-15T10:30:00Z"},
        {~U[2026-12-31 23:59:59.999999Z], "2026-12-31T23:59:59.999999Z"},
        {~U[2026-01-01 00:00:00Z], "2026-01-01T00:00:00Z"}
      ]

      for {scheduled_at, expected_iso8601} <- test_cases do
        job = %GoodJob.Job{
          queue_name: "test",
          scheduled_at: scheduled_at
        }

        notification = Notification.for_job(job)

        assert notification["scheduled_at"] == expected_iso8601
        # Verify it's a valid ISO8601 string
        assert {:ok, _datetime, _offset} = DateTime.from_iso8601(notification["scheduled_at"])
      end
    end

    test "matches Ruby GoodJob notification format" do
      # Ruby GoodJob format: { queue_name: "...", scheduled_at: "..." }
      # In Elixir: %{"queue_name" => "...", "scheduled_at" => "..."}
      scheduled_at = ~U[2026-01-15 10:30:00Z]

      job = %GoodJob.Job{
        queue_name: "default",
        scheduled_at: scheduled_at
      }

      notification = Notification.for_job(job)

      # Verify structure matches Ruby GoodJob expectations
      assert is_map(notification)
      assert Map.has_key?(notification, "queue_name")
      assert Map.has_key?(notification, "scheduled_at")
      assert is_binary(notification["queue_name"])
      assert is_binary(notification["scheduled_at"])

      # Verify scheduled_at is ISO8601 format (Ruby GoodJob expects ISO8601)
      assert String.contains?(notification["scheduled_at"], "T")

      assert String.ends_with?(notification["scheduled_at"], "Z") ||
               String.contains?(notification["scheduled_at"], "+") ||
               String.contains?(notification["scheduled_at"], "-")
    end

    test "handles different queue names" do
      queue_names = ["default", "high_priority", "low_priority", "custom_queue"]

      for queue_name <- queue_names do
        job = %GoodJob.Job{
          queue_name: queue_name,
          scheduled_at: nil
        }

        notification = Notification.for_job(job)

        assert notification["queue_name"] == queue_name
      end
    end
  end

  describe "create/2" do
    test "creates notification with queue_name only when scheduled_at is nil" do
      notification = Notification.create("default", nil)

      assert notification == %{"queue_name" => "default"}
      assert Map.has_key?(notification, "queue_name")
      refute Map.has_key?(notification, "scheduled_at")
    end

    test "creates notification with queue_name and scheduled_at when scheduled_at is provided" do
      scheduled_at = ~U[2026-01-15 10:30:45.123456Z]

      notification = Notification.create("high_priority", scheduled_at)

      assert Map.has_key?(notification, "queue_name")
      assert Map.has_key?(notification, "scheduled_at")
      assert notification["queue_name"] == "high_priority"
      assert notification["scheduled_at"] == "2026-01-15T10:30:45.123456Z"
    end

    test "formats scheduled_at as ISO8601 string" do
      scheduled_at = ~U[2026-01-15 10:30:00Z]

      notification = Notification.create("test", scheduled_at)

      assert notification["scheduled_at"] == "2026-01-15T10:30:00Z"
      # Verify it's a valid ISO8601 string
      assert {:ok, _datetime, _offset} = DateTime.from_iso8601(notification["scheduled_at"])
    end

    test "handles default parameter (nil scheduled_at)" do
      notification = Notification.create("default")

      assert notification == %{"queue_name" => "default"}
      refute Map.has_key?(notification, "scheduled_at")
    end

    test "matches Ruby GoodJob notification format" do
      # Ruby GoodJob format: { queue_name: "...", scheduled_at: "..." }
      scheduled_at = ~U[2026-01-15 10:30:00Z]

      notification = Notification.create("default", scheduled_at)

      # Verify structure matches Ruby GoodJob expectations
      assert is_map(notification)
      assert Map.has_key?(notification, "queue_name")
      assert Map.has_key?(notification, "scheduled_at")
      assert is_binary(notification["queue_name"])
      assert is_binary(notification["scheduled_at"])

      # Verify scheduled_at is ISO8601 format
      assert String.contains?(notification["scheduled_at"], "T")
    end

    test "handles DateTime with different timezone formats" do
      # Test that ISO8601 formatting works with UTC DateTime
      scheduled_at = ~U[2026-01-15 10:30:00Z]

      notification = Notification.create("test", scheduled_at)

      # Should still be valid ISO8601
      assert Map.has_key?(notification, "scheduled_at")
      assert {:ok, _datetime, _offset} = DateTime.from_iso8601(notification["scheduled_at"])
      # Verify the ISO8601 string is properly formatted
      assert String.contains?(notification["scheduled_at"], "T")
      assert String.ends_with?(notification["scheduled_at"], "Z")
    end

    test "handles microsecond precision" do
      # Test with full microsecond precision
      scheduled_at = ~U[2026-01-15 10:30:45.123456Z]

      notification = Notification.create("test", scheduled_at)

      assert notification["scheduled_at"] == "2026-01-15T10:30:45.123456Z"
      # Verify it can be parsed back
      assert {:ok, parsed, _offset} = DateTime.from_iso8601(notification["scheduled_at"])
      assert DateTime.compare(parsed, scheduled_at) == :eq
    end
  end

  describe "Ruby GoodJob format compatibility" do
    test "notification format is JSON-serializable" do
      # Ruby GoodJob sends notifications as JSON via PostgreSQL NOTIFY
      scheduled_at = ~U[2026-01-15 10:30:00Z]

      notification = Notification.create("default", scheduled_at)

      # Should be JSON-serializable (all values are primitives)
      json = Jason.encode!(notification)
      assert is_binary(json)

      # Should be JSON-deserializable
      assert {:ok, decoded} = Jason.decode(json)
      assert decoded == notification
    end

    test "notification format matches Ruby GoodJob structure" do
      # Ruby GoodJob notification structure:
      # { queue_name: "default", scheduled_at: "2026-01-15T10:30:00Z" }
      scheduled_at = ~U[2026-01-15 10:30:00Z]

      notification = Notification.create("default", scheduled_at)

      # Verify all keys are strings (JSON-compatible)
      assert Enum.all?(notification, fn {k, v} -> is_binary(k) and is_binary(v) end)

      # Verify required key exists
      assert Map.has_key?(notification, "queue_name")

      # Verify optional key exists when provided
      assert Map.has_key?(notification, "scheduled_at")

      # Verify scheduled_at is valid ISO8601
      assert {:ok, _datetime, _offset} = DateTime.from_iso8601(notification["scheduled_at"])
    end

    test "notification without scheduled_at matches Ruby GoodJob format" do
      # Ruby GoodJob can send notifications without scheduled_at
      notification = Notification.create("default", nil)

      # Should only have queue_name
      assert notification == %{"queue_name" => "default"}
      assert map_size(notification) == 1
    end
  end
end
