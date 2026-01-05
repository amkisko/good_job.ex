defmodule HabitTracker.Jobs.DailyTaskUpdateJob do
  @moduledoc """
  Job that creates daily tasks for all enabled habits.
  Runs daily via cron to ensure tasks are available for the day.
  """
  use GoodJob.Job,
    queue: "default",
    priority: 10,
    max_attempts: 3,
    timeout: 30_000

  alias HabitTracker.Repo
  alias HabitTracker.Schemas.{Habit, Task}
  import Ecto.Query

  @impl true
  def perform(%{date: date}) when is_struct(date, Date) do
    # Get all enabled habits
    habits = Repo.all(from h in Habit, where: h.enabled == true)

    # Create tasks for each habit if they don't exist
    for habit <- habits do
      create_or_update_task(habit, date)
    end

    {:ok, %{tasks_created: length(habits), date: date}}
  end

  def perform(_args) do
    # Default to today
    perform(%{date: Date.utc_today()})
  end

  defp create_or_update_task(habit, date) do
    case Repo.get_by(Task, habit_id: habit.id, date: date) do
      nil ->
        %Task{}
        |> Task.changeset(%{
          habit_id: habit.id,
          date: date,
          completed: false,
          points_earned: 0,
          completion_count: 0
        })
        |> Repo.insert!()

      task ->
        # Task already exists, ensure it's not completed if it's for today
        if task.completed && date == Date.utc_today() do
          task
          |> Task.changeset(%{completed: false, completed_at: nil})
          |> Repo.update!()
        else
          task
        end
    end
  end
end
