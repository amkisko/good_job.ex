defmodule HabitTracker.Schemas.Streak do
  @moduledoc """
  Schema for tracking streaks (consecutive days of completing habits)
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "streaks" do
    field :current_streak, :integer, default: 0
    field :longest_streak, :integer, default: 0
    field :last_completed_date, :date
    field :calculated_at, :utc_datetime_usec

    belongs_to :habit, HabitTracker.Schemas.Habit

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(streak, attrs) do
    streak
    |> cast(attrs, [:current_streak, :longest_streak, :last_completed_date, :calculated_at, :habit_id])
    |> validate_required([:habit_id])
    |> unique_constraint(:habit_id)
  end
end
