defmodule HabitTracker.Schemas.Task do
  @moduledoc """
  Schema for daily tasks (instances of habits for specific dates)
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "tasks" do
    field :date, :date
    field :completed, :boolean, default: false
    field :completed_at, :utc_datetime_usec
    field :points_earned, :integer, default: 0
    field :completion_count, :integer, default: 0 # Number of times this task has been completed

    belongs_to :habit, HabitTracker.Schemas.Habit

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(task, attrs) do
    task
    |> cast(attrs, [:date, :completed, :completed_at, :points_earned, :completion_count, :habit_id])
    |> validate_required([:date, :habit_id])
    |> validate_number(:completion_count, greater_than_or_equal_to: 0)
    |> unique_constraint([:date, :habit_id], name: :tasks_date_habit_index)
  end
end
