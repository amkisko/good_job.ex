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
           case AdvisoryLock.hash_key(id) do
             lock_key when is_integer(lock_key) ->
               case AdvisoryLock.lock_session(lock_key) do
                 true -> record
                 false -> raise "Failed to acquire advisory lock for process #{id}"
               end

             {:error, reason} ->
               raise "Failed to hash advisory lock key for process #{id}: #{inspect(reason)}"
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
    hash_algorithm = advisory_lock_hash_algorithm()
    join_condition = advisory_lock_join_dynamic(hash_algorithm)

    from(p in __MODULE__,
      left_join: l in subquery(advisory_locks_query()),
      on: ^join_condition,
      where:
        (p.lock_type == 1 and not is_nil(l.classid)) or
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
    hash_algorithm = advisory_lock_hash_algorithm()
    join_condition = advisory_lock_join_dynamic(hash_algorithm)

    from(p in __MODULE__,
      left_join: l in subquery(advisory_locks_query()),
      on: ^join_condition,
      where:
        (p.lock_type == 1 and is_nil(l.classid)) or
          (p.lock_type != 1 and p.updated_at <= ^expired_cutoff)
    )
  end

  defp advisory_locks_query do
    from(l in fragment("pg_locks"),
      where: fragment("locktype = 'advisory' AND objsubid = 1"),
      select: %{classid: fragment("classid"), objid: fragment("objid")},
      distinct: true
    )
  end

  defp advisory_lock_hash_algorithm do
    GoodJob.Config.advisory_lock_hash_algorithm()
    |> to_string()
    |> String.downcase()
  end

  defp advisory_lock_join_dynamic("md5") do
    dynamic([p, l], fragment(
      "? = substring((('x' || substr(md5(?::text), 1, 16))::bit(64)::bigint)::bit(64) from 1 for 32)::bit(32)::int AND ? = substring((('x' || substr(md5(?::text), 1, 16))::bit(64)::bigint)::bit(64) from 33 for 32)::bit(32)::int",
      l.classid,
      p.id,
      l.objid,
      p.id
    ))
  end

  defp advisory_lock_join_dynamic("hashtextextended") do
    dynamic([p, l], fragment(
      "? = substring((hashtextextended(?::text, 0))::bit(64) from 1 for 32)::bit(32)::int AND ? = substring((hashtextextended(?::text, 0))::bit(64) from 33 for 32)::bit(32)::int",
      l.classid,
      p.id,
      l.objid,
      p.id
    ))
  end

  defp advisory_lock_join_dynamic("hashtext") do
    dynamic([p, l], fragment(
      "? = substring((((hashtext(?::text)::bigint << 32) + (hashtext(('good_job-' || ?::text))::bigint & 4294967295::bigint)))::bit(64) from 1 for 32)::bit(32)::int AND ? = substring((((hashtext(?::text)::bigint << 32) + (hashtext(('good_job-' || ?::text))::bigint & 4294967295::bigint)))::bit(64) from 33 for 32)::bit(32)::int",
      l.classid,
      p.id,
      p.id,
      l.objid,
      p.id,
      p.id
    ))
  end

  defp advisory_lock_join_dynamic("uuid_v5") do
    dynamic([p, l], fragment(
      "? = substring((('x' || substr(replace(uuid_generate_v5('6ba7b810-9dad-11d1-80b4-00c04fd430c8'::uuid, ?::text)::text, '-', ''), 1, 16))::bit(64)::bigint)::bit(64) from 1 for 32)::bit(32)::int AND ? = substring((('x' || substr(replace(uuid_generate_v5('6ba7b810-9dad-11d1-80b4-00c04fd430c8'::uuid, ?::text)::text, '-', ''), 1, 16))::bit(64)::bigint)::bit(64) from 33 for 32)::bit(32)::int",
      l.classid,
      p.id,
      l.objid,
      p.id
    ))
  end

  defp advisory_lock_join_dynamic(hash_algorithm) do
    dynamic([p, l], fragment(
      "? = substring((('x' || substr(encode(digest(?::text, ?), 'hex'), 1, 16))::bit(64)::bigint)::bit(64) from 1 for 32)::bit(32)::int AND ? = substring((('x' || substr(encode(digest(?::text, ?), 'hex'), 1, 16))::bit(64)::bigint)::bit(64) from 33 for 32)::bit(32)::int",
      l.classid,
      p.id,
      ^hash_algorithm,
      l.objid,
      p.id,
      ^hash_algorithm
    ))
  end
end
