defmodule HabitTracker.Repo.Migrations.CreateAnalytics do
  use Ecto.Migration

  def change do
    create table(:analytics, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :period, :string, null: false
      add :period_start, :date, null: false
      add :period_end, :date, null: false
      add :completion_rate, :float
      add :total_completions, :integer
      add :total_points, :integer
      add :data, :map

      timestamps(type: :utc_datetime_usec)
    end

    create index(:analytics, [:period])
    create index(:analytics, [:period_start, :period_end])
  end
end
