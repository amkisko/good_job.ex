defmodule HabitTracker.Repo.Migrations.CreateTasks do
  use Ecto.Migration

  def change do
    create table(:tasks, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :date, :date, null: false
      add :completed, :boolean, default: false, null: false
      add :completed_at, :utc_datetime_usec
      add :points_earned, :integer, default: 0, null: false
      add :habit_id, references(:habits, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:tasks, [:date, :habit_id], name: :tasks_date_habit_index)
    create index(:tasks, [:habit_id])
    create index(:tasks, [:date])
    create index(:tasks, [:completed])
  end
end
