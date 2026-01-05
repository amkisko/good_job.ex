defmodule HabitTracker.Repo.Migrations.CreateHabits do
  use Ecto.Migration

  def change do
    create table(:habits, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :text
      add :category, :string, null: false
      add :points_per_completion, :integer, default: 10, null: false
      add :enabled, :boolean, default: true, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:habits, [:category])
    create index(:habits, [:enabled])
  end
end
