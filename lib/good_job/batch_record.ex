defmodule GoodJob.BatchRecord do
  @moduledoc """
  Ecto schema for good_job_batches table.

  Represents a batch of jobs.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "good_job_batches" do
    field(:description, :string)
    field(:serialized_properties, :map)
    field(:on_finish, :string)
    field(:on_success, :string)
    field(:on_discard, :string)
    field(:callback_queue_name, :string)
    field(:callback_priority, :integer)
    field(:enqueued_at, :utc_datetime_usec)
    field(:discarded_at, :utc_datetime_usec)
    field(:finished_at, :utc_datetime_usec)
    field(:jobs_finished_at, :utc_datetime_usec)

    # Map inserted_at field to created_at column
    field(:inserted_at, :utc_datetime_usec, source: :created_at, autogenerate: {DateTime, :utc_now, []})
    field(:updated_at, :utc_datetime_usec, autogenerate: {DateTime, :utc_now, []})
  end

  @doc """
  Creates a changeset for a batch.
  """
  def changeset(batch, attrs) do
    batch
    |> cast(attrs, [
      :description,
      :serialized_properties,
      :on_finish,
      :on_success,
      :on_discard,
      :callback_queue_name,
      :callback_priority,
      :enqueued_at,
      :discarded_at,
      :finished_at,
      :jobs_finished_at
    ])
  end

  @doc """
  Returns a query for batches finished before the given datetime.
  """
  def finished_before(query \\ __MODULE__, cutoff) do
    import Ecto.Query
    where(query, [b], b.finished_at < ^cutoff)
  end
end
