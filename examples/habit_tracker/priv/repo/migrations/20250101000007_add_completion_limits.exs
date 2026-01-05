defmodule HabitTracker.Repo.Migrations.AddCompletionLimits do
  use Ecto.Migration

  def change do
    # Add max_completions to habits (default 1, meaning can complete once per day)
    alter table(:habits) do
      add :max_completions, :integer, default: 1, null: false
    end

    # Add completion_count to tasks (tracks how many times this task has been completed)
    alter table(:tasks) do
      add :completion_count, :integer, default: 0, null: false
    end

    create index(:tasks, [:completion_count])
  end
end
