defmodule GoodJob.Execution do
  @moduledoc """
  Ecto schema for good_job_executions table.

  Represents a job execution record.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "good_job_executions" do
    field(:active_job_id, :binary_id)
    field(:job_class, :string)
    field(:queue_name, :string)
    field(:serialized_params, :map)
    field(:scheduled_at, :utc_datetime_usec)
    field(:finished_at, :utc_datetime_usec)
    field(:error, :string)
    field(:error_event, :integer)
    field(:error_backtrace, {:array, :string})
    field(:process_id, :binary_id)
    # Duration stored as PostgreSQL interval type
    # Using custom type to handle Postgrex.Interval struct
    field(:duration, GoodJob.Types.Interval)

    # Map inserted_at field to created_at column
    field(:inserted_at, :utc_datetime_usec, source: :created_at, autogenerate: {DateTime, :utc_now, []})
    field(:updated_at, :utc_datetime_usec, autogenerate: {DateTime, :utc_now, []})
  end

  @doc """
  Creates a changeset for an execution.
  """
  def changeset(execution, attrs) do
    execution
    |> cast(attrs, [
      :active_job_id,
      :job_class,
      :queue_name,
      :serialized_params,
      :scheduled_at,
      :finished_at,
      :error,
      :error_event,
      :error_backtrace,
      :process_id,
      :duration
    ])
    |> validate_required([:active_job_id])
  end
end
