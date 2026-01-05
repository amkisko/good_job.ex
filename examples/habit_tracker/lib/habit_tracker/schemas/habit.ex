defmodule HabitTracker.Schemas.Habit do
  @moduledoc """
  Schema for habits (washing, walking, going to bed, chores, etc.)
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "habits" do
    field :name, :string
    field :description, :string
    field :category, :string # "hygiene", "exercise", "sleep", "chores"
    field :points_per_completion, :integer, default: 10
    field :max_completions, :integer, default: 1 # Maximum number of times a task can be completed per day
    field :enabled, :boolean, default: true

    has_many :tasks, HabitTracker.Schemas.Task
    has_many :completions, HabitTracker.Schemas.Completion
    has_many :streaks, HabitTracker.Schemas.Streak

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(habit, attrs) do
    habit
    |> cast(attrs, [:name, :description, :category, :points_per_completion, :max_completions, :enabled])
    |> validate_required([:name, :category])
    |> validate_inclusion(:category, ["hygiene", "exercise", "sleep", "chores"])
    |> validate_number(:max_completions, greater_than: 0)
  end
end
