defmodule HabitTracker.Repo.Migrations.CreatePointRecords do
  use Ecto.Migration

  def change do
    create table(:point_records, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :total_points, :integer, default: 0, null: false
      add :points_today, :integer, default: 0, null: false
      add :points_this_week, :integer, default: 0, null: false
      add :points_this_month, :integer, default: 0, null: false
      add :calculated_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end
  end
end
