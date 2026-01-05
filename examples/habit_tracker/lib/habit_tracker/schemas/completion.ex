defmodule HabitTracker.Schemas.Completion do
  @moduledoc """
  Schema for task completions (tracks when tasks are completed)
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "completions" do
    field :completed_at, :utc_datetime_usec
    field :points_earned, :integer

    belongs_to :habit, HabitTracker.Schemas.Habit
    belongs_to :task, HabitTracker.Schemas.Task

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(completion, attrs) do
    completion
    |> cast(attrs, [:completed_at, :points_earned, :habit_id, :task_id])
    |> validate_required([:completed_at, :habit_id, :task_id])
  end
end
