defmodule HabitTracker.Schemas.PointRecord do
  @moduledoc """
  Schema for tracking total points earned
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "point_records" do
    field :total_points, :integer, default: 0
    field :points_today, :integer, default: 0
    field :points_this_week, :integer, default: 0
    field :points_this_month, :integer, default: 0
    field :calculated_at, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(point_record, attrs) do
    point_record
    |> cast(attrs, [:total_points, :points_today, :points_this_week, :points_this_month, :calculated_at])
  end
end
