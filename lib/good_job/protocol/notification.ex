defmodule GoodJob.Protocol.Notification do
  @moduledoc """
  Notification formatting for cross-language GoodJob communication.

  This module handles formatting notifications that are sent via PostgreSQL
  LISTEN/NOTIFY to match Ruby GoodJob's notification format, enabling
  cross-language job dispatch coordination.

  ## Notification Format

  Notifications follow Ruby GoodJob's format:

      %{
        "queue_name" => "default",
        "scheduled_at" => "2026-01-15T10:30:00Z"  # ISO8601 format, optional
      }

  ## Usage

      # Create a notification for a job
      notification = GoodJob.Protocol.Notification.for_job(job)
      GoodJob.Notifier.notify(notification)
  """

  @doc """
  Creates a notification message for a job in Ruby GoodJob format.

  Returns a map with `queue_name` and optionally `scheduled_at` (ISO8601 format).

  ## Examples

      job = %GoodJob.Job{queue_name: "default", scheduled_at: nil}
      notification = GoodJob.Protocol.Notification.for_job(job)
      # => %{"queue_name" => "default"}

      job = %GoodJob.Job{queue_name: "high_priority", scheduled_at: ~U[2026-01-15 10:30:00Z]}
      notification = GoodJob.Protocol.Notification.for_job(job)
      # => %{"queue_name" => "high_priority", "scheduled_at" => "2026-01-15T10:30:00Z"}
  """
  @spec for_job(GoodJob.Job.t()) :: %{String.t() => String.t()}
  def for_job(%{queue_name: queue_name, scheduled_at: scheduled_at}) do
    notification = %{"queue_name" => queue_name}

    if scheduled_at do
      Map.put(notification, "scheduled_at", DateTime.to_iso8601(scheduled_at))
    else
      notification
    end
  end

  @doc """
  Creates a notification message from queue name and optional scheduled_at.

  ## Examples

      GoodJob.Protocol.Notification.create("default", nil)
      # => %{"queue_name" => "default"}

      GoodJob.Protocol.Notification.create("high_priority", ~U[2026-01-15 10:30:00Z])
      # => %{"queue_name" => "high_priority", "scheduled_at" => "2026-01-15T10:30:00Z"}
  """
  @spec create(String.t(), DateTime.t() | nil) :: %{String.t() => String.t()}
  def create(queue_name, scheduled_at \\ nil) do
    notification = %{"queue_name" => queue_name}

    if scheduled_at do
      Map.put(notification, "scheduled_at", DateTime.to_iso8601(scheduled_at))
    else
      notification
    end
  end
end
