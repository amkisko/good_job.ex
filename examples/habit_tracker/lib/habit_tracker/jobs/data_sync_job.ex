defmodule HabitTracker.Jobs.DataSyncJob do
  @moduledoc """
  Mock integration job that simulates syncing data with an external API.
  This demonstrates how to use GoodJob for background integration tasks.
  """
  use GoodJob.Job,
    queue: "integrations",
    priority: 5,
    max_attempts: 5,
    timeout: 30_000

  alias HabitTracker.Repo
  alias HabitTracker.Schemas.{Habit, Completion}
  import Ecto.Query

  @impl true
  def perform(%{sync_type: sync_type}) do
    case sync_type do
      "habits" -> sync_habits()
      "completions" -> sync_completions()
      _ -> {:error, "Unknown sync_type: #{sync_type}"}
    end
  end

  def perform(_args) do
    # Default to syncing completions
    sync_completions()
  end

  defp sync_habits do
    # Mock: Simulate fetching habits from external API
    Process.sleep(500) # Simulate API call

    habits = Repo.all(Habit)

    # Mock: Simulate sending habits to external API
    Process.sleep(300)

    {:ok, %{habits_synced: length(habits), sync_type: "habits"}}
  end

  defp sync_completions do
    # Mock: Simulate fetching recent completions
    Process.sleep(500) # Simulate API call

    # Get completions from last 24 hours
    yesterday = DateTime.add(DateTime.utc_now(), -1, :day)

    completions =
      from(c in Completion,
        where: c.completed_at >= ^yesterday,
        limit: 100
      )

    completion_count = Repo.aggregate(completions, :count, :id)

    # Mock: Simulate sending completions to external API
    Process.sleep(300)

    {:ok, %{completions_synced: completion_count, sync_type: "completions"}}
  end
end
