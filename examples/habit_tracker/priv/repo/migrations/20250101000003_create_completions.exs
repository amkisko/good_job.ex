defmodule HabitTracker.Repo.Migrations.CreateCompletions do
  use Ecto.Migration

  def change do
    create table(:completions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :completed_at, :utc_datetime_usec, null: false
      add :points_earned, :integer, null: false
      add :habit_id, references(:habits, type: :binary_id, on_delete: :delete_all), null: false
      add :task_id, references(:tasks, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:completions, [:habit_id])
    create index(:completions, [:task_id])
    create index(:completions, [:completed_at])
  end
end
