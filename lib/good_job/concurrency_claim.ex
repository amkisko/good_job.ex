defmodule GoodJob.ConcurrencyClaim do
  @moduledoc """
  Granted or waiting claims on a concurrency key or label.

  Matches Ruby GoodJob's `good_job_concurrency_claims` progressive enhancement:
  when the table exists, `perform_limit` uses grant/wait/promote instead of only
  counting running rows. Promotion re-schedules the oldest waiter immediately;
  it does not reserve the freed slot.
  """

  use Ecto.Schema
  import Ecto.Query

  alias GoodJob.{Config, Job, Notifier, Protocol, Repo}

  @type t :: %__MODULE__{}

  @waiting 0
  @granted 1
  @promotion_pending 2
  @promoted 3

  @label_key_prefix "label:"
  @key_key_prefix "key:"

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "good_job_concurrency_claims" do
    field(:job_id, :binary_id)
    field(:locked_by_id, :binary_id)
    field(:state, :integer)
    field(:key, :string)

    field(:inserted_at, :utc_datetime_usec, source: :created_at, autogenerate: {DateTime, :utc_now, []})
    field(:updated_at, :utc_datetime_usec, autogenerate: {DateTime, :utc_now, []})
  end

  def waiting, do: @waiting
  def granted, do: @granted
  def promotion_pending, do: @promotion_pending
  def promoted, do: @promoted
  def label_key_prefix, do: @label_key_prefix

  @doc """
  Builds the claim key for a concurrency label (`label:<name>`).
  """
  def claim_key_for_label(label) when is_binary(label), do: @label_key_prefix <> label

  @doc """
  Builds the claim key for a legacy concurrency column key (`key:<name>`).
  """
  def claim_key_for_concurrency_key(key) when is_binary(key), do: @key_key_prefix <> key

  @doc """
  Returns true when the claims table is present (shared DBs may lag migrations).
  """
  def table_exists? do
    repo = Repo.repo()
    result = Ecto.Adapters.SQL.query!(repo, "SELECT to_regclass('good_job_concurrency_claims') IS NOT NULL", [])
    match?(%{rows: [[true]]}, result)
  rescue
    _ -> false
  end

  @doc """
  Grants a claim when under `limit` running jobs in `scope`; otherwise records WAITING.

  Must run while holding the concurrency advisory lock for the same logical key.
  """
  def claim(opts) do
    key = Keyword.fetch!(opts, :key)
    limit = Keyword.fetch!(opts, :limit)
    scope = Keyword.fetch!(opts, :scope)
    job_id = Keyword.fetch!(opts, :job_id)
    locked_by_id = Keyword.get(opts, :locked_by_id)
    repo = Repo.repo()

    held_count =
      scope
      |> Job.running()
      |> where([j], j.id != ^job_id)
      |> where([j], j.id not in subquery(non_granted_job_ids(key)))
      |> repo.aggregate(:count, :id)

    if held_count < limit do
      upsert_claim(repo, key, job_id, locked_by_id, @granted)
      true
    else
      repo.delete_all(
        from(c in __MODULE__,
          where: c.state in ^[@waiting, @promotion_pending, @promoted],
          where: c.job_id == ^job_id,
          where: c.key != ^key
        )
      )

      upsert_claim(repo, key, job_id, nil, @waiting)
      false
    end
  end

  @doc """
  Releases granted claims for `job_id` and promotes one waiter per freed key.
  """
  def release_job(job_id) when is_binary(job_id) do
    repo = Repo.repo()

    keys =
      repo.all(from(c in __MODULE__, where: c.state == ^@granted and c.job_id == ^job_id, select: c.key))

    if keys != [] do
      repo.delete_all(from(c in __MODULE__, where: c.state == ^@granted and c.job_id == ^job_id))
      Enum.each(keys, &promote_next/1)
    end

    :ok
  end

  @doc """
  Releases granted claims held by a vanished process and promotes waiters.
  """
  def release_process(locked_by_id) when is_binary(locked_by_id) do
    repo = Repo.repo()

    keys =
      repo.all(
        from(c in __MODULE__,
          where: c.state == ^@granted and c.locked_by_id == ^locked_by_id,
          select: c.key
        )
      )

    if keys != [] do
      repo.delete_all(from(c in __MODULE__, where: c.state == ^@granted and c.locked_by_id == ^locked_by_id))

      Enum.each(keys, &promote_next/1)
    end

    :ok
  end

  @doc """
  Finishes claim lifecycle for a job after execution updates are committed.
  """
  def job_finished(%Job{} = job) do
    release_job(job.id)

    case job.finished_at do
      nil ->
        apply_pending_promotion(job.id)

      _ ->
        Repo.repo().delete_all(from(c in __MODULE__, where: c.job_id == ^job.id))
        :ok
    end
  end

  defp apply_pending_promotion(job_id) do
    repo = Repo.repo()

    promoted? =
      repo.transaction(fn ->
        rows =
          from(c in __MODULE__, where: c.job_id == ^job_id)
          |> lock("FOR UPDATE")
          |> repo.all()
          |> Enum.filter(&(&1.state == @promotion_pending))

        if rows == [] do
          false
        else
          ids = Enum.map(rows, & &1.id)
          now = DateTime.utc_now()

          repo.update_all(from(c in __MODULE__, where: c.id in ^ids),
            set: [state: @promoted, updated_at: now]
          )

          schedule_now(job_id)
        end
      end)

    case promoted? do
      {:ok, true} -> notify(job_id)
      _ -> :ok
    end
  end

  defp promote_next(key) do
    repo = Repo.repo()

    result =
      repo.transaction(fn ->
        claim =
          from(c in __MODULE__,
            where: c.state == ^@waiting and c.key == ^key,
            order_by: [asc: c.inserted_at],
            limit: 1,
            lock: "FOR UPDATE SKIP LOCKED"
          )
          |> repo.one()

        cond do
          is_nil(claim) ->
            nil

          not job_unfinished?(claim.job_id) ->
            repo.delete(claim)
            :stale

          schedule_now(claim.job_id) ->
            now = DateTime.utc_now()

            repo.update_all(from(c in __MODULE__, where: c.id == ^claim.id),
              set: [state: @promoted, updated_at: now]
            )

            claim.job_id

          true ->
            now = DateTime.utc_now()

            repo.update_all(from(c in __MODULE__, where: c.id == ^claim.id),
              set: [state: @promotion_pending, updated_at: now]
            )

            nil
        end
      end)

    case result do
      {:ok, :stale} -> promote_next(key)
      {:ok, job_id} when is_binary(job_id) -> notify(job_id)
      _ -> :ok
    end
  end

  defp schedule_now(job_id) do
    repo = Repo.repo()
    now = DateTime.utc_now()

    {count, _} =
      repo.update_all(
        from(j in Job,
          where: j.id == ^job_id,
          where: is_nil(j.performed_at),
          where: is_nil(j.finished_at)
        ),
        set: [scheduled_at: now, updated_at: now]
      )

    count > 0
  end

  defp job_unfinished?(job_id) do
    Repo.repo().exists?(from(j in Job, where: j.id == ^job_id and is_nil(j.finished_at)))
  end

  defp notify(job_id) do
    if Config.enable_listen_notify?() do
      case Repo.repo().get(Job, job_id) do
        %Job{} = job -> Notifier.notify(Protocol.Notification.for_job(job))
        _ -> :ok
      end
    else
      :ok
    end
  end

  defp non_granted_job_ids(key) do
    from(c in __MODULE__, where: c.key == ^key and c.state != ^@granted, select: c.job_id)
  end

  defp upsert_claim(repo, key, job_id, locked_by_id, state) do
    now = DateTime.utc_now()

    %__MODULE__{}
    |> Ecto.Changeset.change(%{
      id: Ecto.UUID.generate(),
      key: key,
      job_id: job_id,
      locked_by_id: locked_by_id,
      state: state,
      inserted_at: now,
      updated_at: now
    })
    |> repo.insert!(
      on_conflict: [
        set: [locked_by_id: locked_by_id, state: state, updated_at: now]
      ],
      conflict_target: [:key, :job_id]
    )
  end
end
