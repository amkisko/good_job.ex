defmodule GoodJob.Job.Claim do
  @moduledoc false

  import Ecto.Query

  require Logger

  alias GoodJob.{AdvisoryLock, Job, JobPerformer}

  @lock_type_skiplocked 1
  @lock_type_hybrid 2
  @max_batch_size 64

  @doc """
  Selects the next job for `:advisory` (advisory xact lock per candidate), or claims a row
  for `:skiplocked` / `:hybrid` (SKIP LOCKED + UPDATE).
  """
  @spec claim_next(Ecto.Repo.t(), map(), Ecto.UUID.t(), atom(), keyword()) :: Job.t() | nil
  def claim_next(repo, parsed_queues, lock_id, strategy, opts \\ []) do
    case claim_many(repo, parsed_queues, lock_id, strategy, 1, opts) do
      [job | _] -> job
      [] -> nil
    end
  end

  @doc """
  Claims up to `limit` jobs in one query for `:skiplocked` / `:hybrid`.

  `:advisory` claims at most one job (same as `claim_next/5`) because each candidate
  needs a separate application-level advisory lock attempt.
  """
  @spec claim_many(Ecto.Repo.t(), map(), Ecto.UUID.t(), atom(), pos_integer(), keyword()) :: [Job.t()]
  def claim_many(repo, parsed_queues, lock_id, strategy, limit, opts \\ [])

  def claim_many(repo, parsed_queues, lock_id, :advisory, _limit, opts) do
    queue_select_limit = Keyword.get(opts, :queue_select_limit) || GoodJob.Config.queue_select_limit() || 1000

    case claim_advisory(repo, parsed_queues, lock_id, queue_select_limit) do
      nil -> []
      job -> [job]
    end
  end

  def claim_many(repo, parsed_queues, lock_id, :skiplocked, limit, _opts) do
    claim_skip_locked_many(repo, parsed_queues, lock_id, normalize_batch_limit(limit))
  end

  def claim_many(repo, parsed_queues, lock_id, :hybrid, limit, _opts) do
    claim_hybrid_many(repo, parsed_queues, lock_id, normalize_batch_limit(limit))
  end

  defp normalize_batch_limit(limit) when is_integer(limit) and limit > 0 do
    min(limit, @max_batch_size)
  end

  defp normalize_batch_limit(_), do: 1

  defp claim_advisory(repo, parsed_queues, _lock_id, queue_select_limit) do
    now = DateTime.utc_now()

    query =
      Job
      |> Job.unfinished()
      |> Job.unlocked()
      |> Job.exclude_paused()
      |> JobPerformer.filter_queues(parsed_queues)
      |> where([j], is_nil(j.scheduled_at) or j.scheduled_at <= ^now)
      |> Job.order_for_candidate_lookup(parsed_queues)
      |> limit(^queue_select_limit)

    candidates = repo.all(query)

    Enum.find_value(candidates, fn job ->
      lock_key = AdvisoryLock.job_id_to_lock_key(job.id)

      case AdvisoryLock.lock(lock_key) do
        true -> job
        false -> nil
      end
    end)
  end

  defp claim_skip_locked_many(repo, parsed_queues, lock_id, limit) do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)
    {sql, params} = skip_locked_claim_sql(repo, parsed_queues, lock_id, now, @lock_type_skiplocked, limit)

    case Ecto.Adapters.SQL.query(repo, sql, params) do
      {:ok, %{rows: rows, columns: columns}} when rows != [] ->
        Enum.map(rows, &load_claimed_job(repo, columns, &1))

      {:ok, %{rows: _}} ->
        []

      {:error, err} ->
        Logger.warning("GoodJob.Job.Claim skip_locked claim query failed: #{inspect(err)}")
        []
    end
  end

  defp claim_hybrid_many(repo, parsed_queues, lock_id, limit) do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)
    {sql, params} = hybrid_claim_sql(repo, parsed_queues, lock_id, now, @lock_type_hybrid, limit)

    # Keep claim + advisory unlock on one checked-out connection (session lock).
    repo.checkout(fn ->
      case Ecto.Adapters.SQL.query(repo, sql, params) do
        {:ok, %{rows: []}} ->
          []

        {:ok, %{rows: rows, columns: columns}} ->
          jobs = Enum.map(rows, &load_claimed_job(repo, columns, &1))
          Enum.each(jobs, &unlock_hybrid_session_advisory(repo, &1.id))
          jobs

        {:error, err} ->
          Logger.warning("GoodJob.Job.Claim hybrid claim query failed: #{inspect(err)}")
          []
      end
    end)
  end

  defp skip_locked_claim_sql(repo, parsed_queues, lock_id, now, lock_type, limit) do
    {inner_sql, inner_params} = candidate_select_sql(repo, parsed_queues, now, limit)
    k = length(inner_params)

    sql = """
    WITH candidate AS MATERIALIZED (#{inner_sql})
    UPDATE good_jobs AS gj
    SET locked_by_id = $#{k + 1}::uuid,
        locked_at = $#{k + 2}::timestamptz,
        lock_type = $#{k + 3}::smallint
    FROM candidate
    WHERE gj.id = candidate.id
    RETURNING gj.*
    """

    {sql, inner_params ++ [uuid_param!(lock_id), now, lock_type]}
  end

  # Session `pg_try_advisory_lock` in SQL uses the MD5 expression below. It does not follow
  # `GoodJob.Config.advisory_lock_hash_algorithm` (that applies to Elixir `AdvisoryLock` and
  # `:advisory` dequeue). See `GoodJob.Config` docs for `:lock_strategy` / `:advisory_lock_hash_algorithm`.
  defp hybrid_claim_sql(repo, parsed_queues, lock_id, now, lock_type, limit) do
    {inner_sql, inner_params} = candidate_select_sql(repo, parsed_queues, now, limit)
    k = length(inner_params)
    advisory_expr = hybrid_advisory_lock_expr()

    sql = """
    WITH candidate AS MATERIALIZED (#{inner_sql})
    UPDATE good_jobs AS gj
    SET locked_by_id = $#{k + 1}::uuid,
        locked_at = $#{k + 2}::timestamptz,
        lock_type = $#{k + 3}::smallint
    FROM (
      SELECT id FROM candidate
      WHERE pg_try_advisory_lock(#{advisory_expr})
    ) AS locked
    WHERE gj.id = locked.id
    RETURNING gj.*
    """

    {sql, inner_params ++ [uuid_param!(lock_id), now, lock_type]}
  end

  defp uuid_param!(uuid) do
    case Ecto.UUID.dump(uuid) do
      {:ok, dumped} ->
        dumped

      :error ->
        if is_binary(uuid) and byte_size(uuid) == 16 do
          uuid
        else
          raise ArgumentError, "expected UUID, got: #{inspect(uuid)}"
        end
    end
  end

  defp load_claimed_job(repo, columns, row) do
    repo.load(Job, Map.new(Enum.zip(columns, row)))
  end

  defp candidate_select_sql(repo, parsed_queues, %DateTime{} = now, limit) do
    q =
      Job
      |> Job.unfinished()
      |> Job.unlocked()
      |> Job.exclude_paused()
      |> JobPerformer.filter_queues(parsed_queues)
      |> where([j], is_nil(j.scheduled_at) or j.scheduled_at <= ^now)
      |> Job.order_for_candidate_lookup(parsed_queues)
      |> limit(^limit)
      |> select([j], j.id)
      |> lock("FOR NO KEY UPDATE SKIP LOCKED")

    Ecto.Adapters.SQL.to_sql(:all, repo, q)
  end

  # Fixed MD5-based bigint; must match `AdvisoryLock` default job-id derivation for consistency.
  defp hybrid_advisory_lock_expr do
    "('x' || substr(md5('good_jobs' || '-' || id::text), 1, 16))::bit(64)::bigint"
  end

  defp unlock_hybrid_session_advisory(repo, job_id) do
    sql =
      "SELECT pg_advisory_unlock( ( 'x' || substr(md5('good_jobs' || '-' || $1::text), 1, 16))::bit(64)::bigint )"

    uuid_text = Ecto.UUID.cast!(job_id)
    _ = Ecto.Adapters.SQL.query!(repo, sql, [uuid_text])
    :ok
  end
end
