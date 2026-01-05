defmodule HabitTracker.Repo.Migrations.CreateStreaks do
  use Ecto.Migration

  def change do
    create table(:streaks, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :current_streak, :integer, default: 0, null: false
      add :longest_streak, :integer, default: 0, null: false
      add :last_completed_date, :date
      add :calculated_at, :utc_datetime_usec
      add :habit_id, references(:habits, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:streaks, [:habit_id])
    create index(:streaks, [:current_streak])
  end
end
