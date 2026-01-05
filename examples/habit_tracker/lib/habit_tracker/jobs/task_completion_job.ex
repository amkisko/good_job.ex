defmodule HabitTracker.Jobs.TaskCompletionJob do
  @moduledoc """
  Job that handles task completion (marks task as completed, creates completion record, awards points).
  This demonstrates using GoodJob for user-triggered actions.
  """
  use GoodJob.Job,
    queue: "default",
    priority: 20,
    max_attempts: 3,
    timeout: 10_000

  alias HabitTracker.Repo
  alias HabitTracker.Schemas.{Task, Completion}

  @impl true
  def perform(args) when is_map(args) do
    # Handle both atom and string keys (GoodJob deserializes with string keys)
    task_id = Map.get(args, :task_id) || Map.get(args, "task_id")

    unless task_id && is_binary(task_id) do
      {:error, "task_id is required and must be a binary (UUID)"}
    else
      # task_id is a UUID (binary_id), not an integer
      task = Repo.get!(Task, task_id) |> Repo.preload(:habit)

      max_completions = task.habit.max_completions || 1
      current_count = task.completion_count || 0

      if current_count >= max_completions do
        {:ok, %{message: "Task completion limit reached", task_id: task_id, completion_count: current_count, max_completions: max_completions}}
      else
        now = DateTime.utc_now()
        points = task.habit.points_per_completion
        new_count = current_count + 1

        # Only award points if this completion is within the limit
        # (points are only awarded for the first max_completions completions)
        points_to_award = if new_count <= max_completions, do: points, else: 0

        # Update task: increment completion_count, update completed_at, add points
        task
        |> Task.changeset(%{
          completed: true, # Mark as completed (even if at limit, it's still "completed")
          completed_at: now,
          completion_count: new_count,
          points_earned: (task.points_earned || 0) + points_to_award
        })
        |> Repo.update!()

        # Create completion record (always create for tracking, even if no points awarded)
        %Completion{}
        |> Completion.changeset(%{
          habit_id: task.habit_id,
          task_id: task.id,
          completed_at: now,
          points_earned: points_to_award
        })
        |> Repo.insert!()

        # Enqueue analytics job to update stats
        # Date structs are automatically serialized in ActiveJob format
        HabitTracker.Jobs.AnalyticsJob.perform_later(%{
          period: "daily",
          period_start: task.date,
          period_end: task.date
        })

        # Enqueue points calculation job to update point records immediately
        HabitTracker.Jobs.PointsCalculationJob.perform_later(%{})

        {:ok, %{task_id: task_id, points_earned: points_to_award, completion_count: new_count, max_completions: max_completions, completed_at: now}}
      end
    end
  end

  def perform(_args) do
    {:error, "task_id is required"}
  end
end
