defmodule GoodJob.PubSub do
  @moduledoc """
  Broadcasts job events to Phoenix.PubSub for real-time LiveView updates.

  This allows LiveViews to subscribe to job events and update automatically
  when jobs are created, updated, or completed.

  **Note:** This module is optional and requires Phoenix to be available.
  If Phoenix is not available, all functions will gracefully no-op.
  The core GoodJob library works perfectly fine without Phoenix.
  """

  @topic "good_job:jobs"

  @doc """
  Broadcasts a job event to all subscribers.

  Events:
  - `:job_created` - A new job was enqueued
  - `:job_updated` - A job's state changed (e.g., started running)
  - `:job_completed` - A job finished (succeeded or discarded)
  - `:job_deleted` - A job was deleted
  - `:job_retried` - A job was retried
  - `:job_discarded` - A job was discarded

  Returns `:ok` if broadcast succeeded, `:noop` if Phoenix is not available.
  """
  def broadcast(event, job_id)
      when event in [
             :job_created,
             :job_updated,
             :job_completed,
             :job_deleted,
             :job_retried,
             :job_discarded,
             :job_exhausted,
             :job_retrying,
             :job_cancelled,
             :job_snoozed
           ] do
    # Check if Phoenix.PubSub is available
    case Code.ensure_loaded(Phoenix.PubSub) do
      {:module, _} ->
        # Try to get PubSub from application config
        pubsub_server = get_pubsub_server()

        if pubsub_server do
          Phoenix.PubSub.broadcast(
            pubsub_server,
            @topic,
            {event, job_id}
          )
        else
          :noop
        end

      {:error, _} ->
        # Phoenix not available - gracefully no-op
        :noop
    end
  end

  # Catch-all for unknown events - gracefully no-op
  def broadcast(_event, _job_id), do: :noop

  @doc """
  Subscribes to job events.

  Returns the topic name for use in LiveView subscriptions, or `nil` if Phoenix is not available.
  """
  def subscribe(pubsub_server \\ nil) do
    # Check if Phoenix.PubSub is available
    case Code.ensure_loaded(Phoenix.PubSub) do
      {:module, _} ->
        server = pubsub_server || get_pubsub_server()

        if server do
          Phoenix.PubSub.subscribe(server, @topic)
          @topic
        else
          nil
        end

      {:error, _} ->
        # Phoenix not available - gracefully return nil
        nil
    end
  end

  defp get_pubsub_server do
    Application.get_env(:good_job, :config, %{})[:pubsub_server] ||
      Application.get_env(:good_job, :pubsub_server)
  end
end
