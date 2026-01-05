defmodule HabitTracker.Jobs.StreakCalculationJob do
  @moduledoc """
  Job that calculates streaks for all habits based on task completions.
  Runs daily via cron to update streak information.
  """
  use GoodJob.Job,
    queue: "default",
    priority: 10,
    max_attempts: 3,
    timeout: 60_000

  alias HabitTracker.Repo
  alias HabitTracker.Schemas.{Habit, Task, Streak}
  import Ecto.Query

  @impl true
  def perform(_args) do
    habits = Repo.all(from h in Habit, where: h.enabled == true)

    results =
      for habit <- habits do
        calculate_streak(habit)
      end

    {:ok, %{habits_processed: length(habits), results: results}}
  end

  defp calculate_streak(habit) do
    # Get all completed tasks ordered by date descending
    completed_tasks =
      from t in Task,
        where: t.habit_id == ^habit.id and t.completed == true,
        order_by: [desc: t.date],
        select: t.date

    completed_dates = Repo.all(completed_tasks)

    if Enum.empty?(completed_dates) do
      # No completions, reset streak
      update_streak(habit, 0, 0, nil)
      %{habit_id: habit.id, current_streak: 0, longest_streak: 0}
    else
      # Calculate current streak (consecutive days from today backwards)
      today = Date.utc_today()
      current_streak = calculate_current_streak(completed_dates, today)

      # Calculate longest streak (all time)
      longest_streak = calculate_longest_streak(completed_dates)

      last_completed = List.first(completed_dates)
      update_streak(habit, current_streak, longest_streak, last_completed)

      %{
        habit_id: habit.id,
        current_streak: current_streak,
        longest_streak: longest_streak,
        last_completed: last_completed
      }
    end
  end

  defp calculate_current_streak(completed_dates, today) do
    # Check if today is completed
    if today in completed_dates do
      # Count consecutive days backwards from today
      count_consecutive_days(completed_dates, today, 0)
    else
      # Check yesterday
      yesterday = Date.add(today, -1)
      if yesterday in completed_dates do
        count_consecutive_days(completed_dates, yesterday, 0)
      else
        0
      end
    end
  end

  defp count_consecutive_days(completed_dates, date, count) do
    if date in completed_dates do
      previous_day = Date.add(date, -1)
      count_consecutive_days(completed_dates, previous_day, count + 1)
    else
      count
    end
  end

  defp calculate_longest_streak(completed_dates) do
    # Sort dates ascending
    sorted_dates = Enum.sort(completed_dates)

    # Find longest consecutive sequence
    find_longest_sequence(sorted_dates, 0, 0, nil)
  end

  defp find_longest_sequence([], _current, max, _last), do: max

  defp find_longest_sequence([date | rest], current, max, last_date) do
    new_current =
      if last_date && Date.diff(date, last_date) == 1 do
        current + 1
      else
        1
      end

    new_max = max(new_current, max)
    find_longest_sequence(rest, new_current, new_max, date)
  end

  defp update_streak(habit, current_streak, longest_streak, last_completed) do
    case Repo.get_by(Streak, habit_id: habit.id) do
      nil ->
        %Streak{}
        |> Streak.changeset(%{
          habit_id: habit.id,
          current_streak: current_streak,
          longest_streak: longest_streak,
          last_completed_date: last_completed,
          calculated_at: DateTime.utc_now()
        })
        |> Repo.insert!()

      streak ->
        streak
        |> Streak.changeset(%{
          current_streak: current_streak,
          longest_streak: max(streak.longest_streak, longest_streak),
          last_completed_date: last_completed,
          calculated_at: DateTime.utc_now()
        })
        |> Repo.update!()
    end
  end
end
