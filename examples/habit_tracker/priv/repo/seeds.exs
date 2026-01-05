alias HabitTracker.Repo
alias HabitTracker.Schemas.Habit
alias GoodJob.Job
import Ecto.Query

# Create default habits
# max_completions: number of times a task can be completed per day to earn points
habits = [
  %{
    name: "Brush Teeth",
    description: "Brush teeth in the morning and evening",
    category: "hygiene",
    points_per_completion: 10,
    max_completions: 2, # Can brush twice per day
    enabled: true
  },
  %{
    name: "Wash Hands",
    description: "Wash hands before meals",
    category: "hygiene",
    points_per_completion: 5,
    max_completions: 3, # Can wash hands 3 times per day (breakfast, lunch, dinner)
    enabled: true
  },
  %{
    name: "Morning Walk",
    description: "Take a 30-minute walk in the morning",
    category: "exercise",
    points_per_completion: 20,
    max_completions: 1, # Once per day
    enabled: true
  },
  %{
    name: "Bedtime Routine",
    description: "Follow bedtime routine (brush teeth, put on pajamas, read a book)",
    category: "sleep",
    points_per_completion: 15,
    max_completions: 1, # Once per day
    enabled: true
  },
  %{
    name: "Make Bed",
    description: "Make the bed in the morning",
    category: "chores",
    points_per_completion: 10,
    max_completions: 1, # Once per day
    enabled: true
  },
  %{
    name: "Clean Room",
    description: "Put away toys and tidy up room",
    category: "chores",
    points_per_completion: 15,
    max_completions: 2, # Can clean room twice per day
    enabled: true
  },
  %{
    name: "Help with Dishes",
    description: "Help clear the table after meals",
    category: "chores",
    points_per_completion: 10,
    max_completions: 3, # Can help with dishes 3 times per day (breakfast, lunch, dinner)
    enabled: true
  }
]

# Idempotently create habits
{created_count, skipped_count} =
  Enum.reduce(habits, {0, 0}, fn habit_attrs, {created_acc, skipped_acc} ->
    case Repo.get_by(Habit, name: habit_attrs.name) do
      nil ->
        # Create new habit
        case %Habit{}
             |> Habit.changeset(habit_attrs)
             |> Repo.insert() do
          {:ok, _habit} ->
            {created_acc + 1, skipped_acc}

          {:error, changeset} ->
            IO.puts("⚠️  Failed to create habit '#{habit_attrs.name}': #{inspect(changeset.errors)}")
            {created_acc, skipped_acc}
        end

      existing ->
        # Update existing habit if attributes have changed (idempotent update)
        changeset = Habit.changeset(existing, habit_attrs)

        if changeset.changes != %{} do
          case Repo.update(changeset) do
            {:ok, _habit} ->
              {created_acc + 1, skipped_acc}

            {:error, changeset} ->
              IO.puts("⚠️  Failed to update habit '#{habit_attrs.name}': #{inspect(changeset.errors)}")
              {created_acc, skipped_acc}
          end
        else
          {created_acc, skipped_acc + 1}
        end
    end
  end)

if created_count > 0 do
  IO.puts("✅ Created/updated #{created_count} habit(s)")
end

if skipped_count > 0 do
  IO.puts("ℹ️  Skipped #{skipped_count} habit(s) (already exist with same values)")
end

# Create today's tasks (idempotent - only enqueue if not already enqueued)
today = Date.utc_today()
today_iso = Date.to_iso8601(today)

# Check if a job for today already exists (not finished)
existing_job =
  Job
  |> where([j], j.job_class == ^"HabitTracker.Jobs.DailyTaskUpdateJob")
  |> where([j], fragment("?->>'date' = ?", j.serialized_params, ^today_iso))
  |> where([j], is_nil(j.finished_at))
  |> Repo.one()

if existing_job == nil do
  case HabitTracker.Jobs.DailyTaskUpdateJob.perform_later(%{date: today}) do
    {:ok, _job} ->
      IO.puts("✅ Enqueued daily task update job for #{today}")

    {:error, changeset} ->
      IO.puts("⚠️  Failed to enqueue daily task update job: #{inspect(changeset.errors)}")
  end
else
  IO.puts("ℹ️  Daily task update job for #{today} already exists, skipping")
end
