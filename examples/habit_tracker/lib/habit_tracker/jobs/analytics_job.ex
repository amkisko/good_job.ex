defmodule HabitTracker.Jobs.AnalyticsJob do
  @moduledoc """
  Job that calculates analytics (completion rates, trends, etc.).
  Can be enqueued manually or via cron for periodic analytics updates.
  """
  use GoodJob.Job,
    queue: "analytics",
    priority: 5,
    max_attempts: 3,
    timeout: 90_000

  alias HabitTracker.Repo
  alias HabitTracker.Schemas.{Task, Analytics, Habit}
  import Ecto.Query

  @impl true
  def perform(%{period: period, period_start: period_start, period_end: period_end}) do
    # Get all tasks in the period
    tasks =
      from t in Task,
        where: t.date >= ^period_start and t.date <= ^period_end,
        preload: [:habit]

    total_tasks = Repo.aggregate(tasks, :count, :id)
    completed_tasks = Repo.aggregate(tasks |> where([t], t.completed == true), :count, :id)

    completion_rate =
      if total_tasks > 0 do
        completed_tasks / total_tasks
      else
        0.0
      end

    # Calculate total points in period
    total_points =
      Repo.one(
        from t in Task,
          where: t.date >= ^period_start and t.date <= ^period_end and t.completed == true,
          select: sum(t.points_earned)
      ) || 0

    # Get completion breakdown by habit
    query =
      from t in Task,
        where: t.date >= ^period_start and t.date <= ^period_end and t.completed == true,
        join: h in Habit,
        on: t.habit_id == h.id,
        group_by: [h.id, h.name],
        select: {h.id, h.name, count(t.id), sum(t.points_earned)}

    habit_completions =
      query
      |> Repo.all()
      |> Enum.map(fn {habit_id, habit_name, completions, points} ->
        %{
          habit_id: habit_id,
          habit_name: habit_name,
          completions: completions,
          points: points
        }
      end)

    # Create analytics record
    analytics =
      %Analytics{}
      |> Analytics.changeset(%{
        period: period,
        period_start: period_start,
        period_end: period_end,
        completion_rate: completion_rate,
        total_completions: completed_tasks,
        total_points: total_points,
        data: %{
          total_tasks: total_tasks,
          habit_completions: habit_completions
        }
      })
      |> Repo.insert!()

    {:ok,
     %{
       analytics_id: analytics.id,
       period: period,
       completion_rate: completion_rate,
       total_completions: completed_tasks,
       total_points: total_points
     }}
  end

  def perform(_args) do
    # Default to today
    today = Date.utc_today()
    perform(%{period: "daily", period_start: today, period_end: today})
  end
end
