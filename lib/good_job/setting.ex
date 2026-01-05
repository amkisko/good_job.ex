defmodule GoodJob.SettingSchema do
  @moduledoc """
  Ecto schema for good_job_settings table.

  Represents a GoodJob setting.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "good_job_settings" do
    field(:key, :string)
    field(:value, :map)

    # Map inserted_at field to created_at column
    field(:inserted_at, :utc_datetime_usec, source: :created_at, autogenerate: {DateTime, :utc_now, []})
    field(:updated_at, :utc_datetime_usec, autogenerate: {DateTime, :utc_now, []})
  end

  @doc """
  Creates a changeset for a setting.
  """
  def changeset(setting, attrs) do
    setting
    |> cast(attrs, [:key, :value])
    |> validate_required([:key])
    |> unique_constraint(:key)
  end
end
