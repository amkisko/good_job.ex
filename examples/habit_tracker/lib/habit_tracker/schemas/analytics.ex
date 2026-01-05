defmodule HabitTracker.Schemas.Analytics do
  @moduledoc """
  Schema for analytics data (completion rates, trends, etc.)
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "analytics" do
    field :period, :string # "daily", "weekly", "monthly"
    field :period_start, :date
    field :period_end, :date
    field :completion_rate, :float
    field :total_completions, :integer
    field :total_points, :integer
    field :data, :map # JSON field for flexible analytics data

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(analytics, attrs) do
    analytics
    |> cast(attrs, [:period, :period_start, :period_end, :completion_rate, :total_completions, :total_points, :data])
    |> validate_required([:period, :period_start, :period_end])
    |> validate_inclusion(:period, ["daily", "weekly", "monthly"])
  end
end
