defmodule GoodJob.Job.Claim do
  @moduledoc false

  import Ecto.Query

  require Logger

  alias GoodJob.{AdvisoryLock, Job, JobPerformer}

  @lock_type_skiplocked 1
  @lock_type_hybrid 2

  @doc """
  Selects the next job for `:advisory` (advisory xact lock per candidate), or claims a row
  for `:skiplocked` / `:hybrid` (SKIP LOCKED + UPDATE).
  """
  @spec claim_next(Ecto.Repo.t(), map(), Ecto.UUID.t(), atom(), keyword()) :: Job.t() | nil
  def claim_next(repo, parsed_queues, lock_id, :advisory, opts) do
    queue_select_limit = Keyword.get(opts, :queue_select_limit) || GoodJob.Config.queue_select_limit() || 1000
    claim_advisory(repo, parsed_queues, lock_id, queue_select_limit)
  end

  def claim_next(repo, parsed_queues, lock_id, :skiplocked, _opts) do
    claim_skip_locked(repo, parsed_queues, lock_id)
  end

  def claim_next(repo, parsed_queues, lock_id, :hybrid, _opts) do
    claim_hybrid(repo, parsed_queues, lock_id)
  end

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

  defp claim_skip_locked(repo, parsed_queues, lock_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)
    {sql, params} = skip_locked_claim_sql(repo, parsed_queues, lock_id, now, @lock_type_skiplocked)

    case Ecto.Adapters.SQL.query(repo, sql, params) do
      {:ok, %{rows: [[id] | _]}} ->
        repo.get(Job, id)

      {:ok, %{rows: _}} ->
        nil

      {:error, err} ->
        Logger.warning("GoodJob.Job.Claim skip_locked claim query failed: #{inspect(err)}")
        nil
    end
  end

  defp claim_hybrid(repo, parsed_queues, lock_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)
    {sql, params} = hybrid_claim_sql(repo, parsed_queues, lock_id, now, @lock_type_hybrid)

    job_id =
      repo.checkout(fn conn ->
        case Ecto.Adapters.SQL.query(repo, sql, params, connection: conn) do
          {:ok, %{rows: []}} ->
            nil

          {:ok, %{rows: [[id] | _]}} ->
            unlock_hybrid_session_advisory(repo, conn, id)
            id

          {:ok, %{rows: _}} ->
            nil

          {:error, err} ->
            Logger.warning("GoodJob.Job.Claim hybrid claim query failed: #{inspect(err)}")
            nil
        end
      end)

    if job_id, do: repo.get(Job, job_id), else: nil
  end

  defp skip_locked_claim_sql(repo, parsed_queues, lock_id, now, lock_type) do
    {inner_sql, inner_params} = candidate_select_sql(repo, parsed_queues, now)
    k = length(inner_params)

    sql = """
    WITH candidate AS MATERIALIZED (#{inner_sql})
    UPDATE good_jobs AS gj
    SET locked_by_id = $#{k + 1}::uuid,
        locked_at = $#{k + 2}::timestamptz,
        lock_type = $#{k + 3}::smallint
    FROM candidate
    WHERE gj.id = candidate.id
    RETURNING gj.id
    """

    {sql, inner_params ++ [lock_id, now, lock_type]}
  end

  # Session `pg_try_advisory_lock` in SQL uses the MD5 expression below. It does not follow
  # `GoodJob.Config.advisory_lock_hash_algorithm` (that applies to Elixir `AdvisoryLock` and
  # `:advisory` dequeue). See `GoodJob.Config` docs for `:lock_strategy` / `:advisory_lock_hash_algorithm`.
  defp hybrid_claim_sql(repo, parsed_queues, lock_id, now, lock_type) do
    {inner_sql, inner_params} = candidate_select_sql(repo, parsed_queues, now)
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
    RETURNING gj.id
    """

    {sql, inner_params ++ [lock_id, now, lock_type]}
  end

  defp candidate_select_sql(repo, parsed_queues, %DateTime{} = now) do
    q =
      Job
      |> Job.unfinished()
      |> Job.unlocked()
      |> Job.exclude_paused()
      |> JobPerformer.filter_queues(parsed_queues)
      |> where([j], is_nil(j.scheduled_at) or j.scheduled_at <= ^now)
      |> Job.order_for_candidate_lookup(parsed_queues)
      |> limit(1)
      |> select([j], j.id)
      |> lock("FOR NO KEY UPDATE SKIP LOCKED")

    Ecto.Adapters.SQL.to_sql(:all, repo, q)
  end

  # Fixed MD5-based bigint; must match `AdvisoryLock` default job-id derivation for consistency.
  defp hybrid_advisory_lock_expr do
    "('x' || substr(md5('good_jobs' || '-' || id::text), 1, 16))::bit(64)::bigint"
  end

  defp unlock_hybrid_session_advisory(repo, conn, job_id) do
    sql =
      "SELECT pg_advisory_unlock( ( 'x' || substr(md5('good_jobs' || '-' || $1::text), 1, 16))::bit(64)::bigint )"

    uuid_text = Ecto.UUID.cast!(job_id)
    _ = Ecto.Adapters.SQL.query!(repo, sql, [uuid_text], connection: conn)
    :ok
  end
end
