defmodule GoodJob.Process do
  @moduledoc """
  Ecto schema for good_job_processes table.

  Represents a GoodJob process record.
  """

  use Ecto.Schema
  import Ecto.Query
  import Ecto.Changeset

  alias GoodJob.AdvisoryLock

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  # Interval until the process record is treated as expired
  @expired_interval_minutes 5

  schema "good_job_processes" do
    field(:state, :map)
    field(:lock_type, :integer)

    # Map inserted_at field to created_at column
    field(:inserted_at, :utc_datetime_usec, source: :created_at, autogenerate: {DateTime, :utc_now, []})
    field(:updated_at, :utc_datetime_usec, autogenerate: {DateTime, :utc_now, []})
  end

  @doc """
  Creates a changeset for a process.
  """
  def changeset(process, attrs) do
    process
    |> cast(attrs, [:state, :lock_type])
  end

  @doc """
  Finds or creates a process record.
  """
  def find_or_create_record(id: id, with_advisory_lock: false) do
    repo = GoodJob.Repo.repo()

    case repo.get(__MODULE__, id) do
      nil ->
        %__MODULE__{id: id}
        |> changeset(%{state: %{}, lock_type: 0})
        |> repo.insert!()

      record ->
        record
    end
  end

  def find_or_create_record(id: id, with_advisory_lock: true) do
    repo = GoodJob.Repo.repo()

    case repo.transaction(fn ->
           record =
             case repo.get(__MODULE__, id) do
               nil ->
                 %__MODULE__{id: id}
                 |> changeset(%{state: %{}, lock_type: 1})
                 |> repo.insert!()

               existing ->
                 existing
             end

           # Acquire advisory lock on the process ID
           lock_key = AdvisoryLock.hash_key(id)

           case AdvisoryLock.lock(lock_key) do
             true -> record
             false -> raise "Failed to acquire advisory lock for process #{id}"
           end
         end) do
      {:ok, record} -> {:ok, record}
      {:error, _} = error -> error
    end
  end

  @doc """
  Returns a query for active processes.

  A process is considered active if:
  - It has lock_type = 1 (advisory) and the advisory lock is currently held, OR
  - It has lock_type != 1 and was updated within the expired interval (5 minutes)
  """
  def active do
    expired_cutoff = DateTime.add(DateTime.utc_now(), -@expired_interval_minutes * 60, :second)

    from(p in __MODULE__,
      left_join: l in subquery(advisory_locks_query()),
      on: fragment("hashtext(?::text) = ?", p.id, l.objid),
      where:
        (p.lock_type == 1 and not is_nil(l.objid)) or
          (p.lock_type != 1 and p.updated_at > ^expired_cutoff)
    )
  end

  @doc """
  Returns a query for inactive processes.

  A process is considered inactive if:
  - It has lock_type = 1 (advisory) and the advisory lock is NOT currently held, OR
  - It has lock_type != 1 and was updated more than the expired interval (5 minutes) ago
  """
  def inactive do
    expired_cutoff = DateTime.add(DateTime.utc_now(), -@expired_interval_minutes * 60, :second)

    from(p in __MODULE__,
      left_join: l in subquery(advisory_locks_query()),
      on: fragment("hashtext(?::text) = ?", p.id, l.objid),
      where:
        (p.lock_type == 1 and is_nil(l.objid)) or
          (p.lock_type != 1 and p.updated_at <= ^expired_cutoff)
    )
  end

  defp advisory_locks_query do
    from(l in fragment("pg_locks"),
      where: fragment("locktype = 'advisory' AND objsubid IN (1, 2)"),
      select: %{objid: fragment("objid")},
      distinct: true
    )
  end
end
