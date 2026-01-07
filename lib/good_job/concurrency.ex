defmodule GoodJob.Concurrency do
  @moduledoc """
  Concurrency control for jobs.

  Allows limiting the number of concurrent jobs per concurrency key,
  and throttling job enqueueing/execution.
  """

  require Logger
  alias GoodJob.{AdvisoryLock, Execution, Job, Repo}
  import Ecto.Query

  @doc """
  Checks if a job can be enqueued based on concurrency limits.

  Returns `:ok` if allowed, `{:error, :limit_exceeded}` or `{:error, :throttle_exceeded}` if not.
  """
  def check_enqueue_limit(concurrency_key, config) when is_binary(concurrency_key) do
    repo = Repo.repo()

    repo.transaction(fn ->
      lock_key = AdvisoryLock.key_to_lock_key(concurrency_key)

      case AdvisoryLock.lock(lock_key) do
        true ->
          check_limits(concurrency_key, config, :enqueue, repo)

        false ->
          {:error, :lock_failed}
      end
    end)
  end

  def check_enqueue_limit(nil, _config) do
    {:ok, :ok}
  end

  @doc """
  Checks if a job can be performed based on concurrency limits.

  Returns `:ok` if allowed, `{:error, :limit_exceeded}` or `{:error, :throttle_exceeded}` if not.
  """
  def check_perform_limit(concurrency_key, job_id, config) when is_binary(concurrency_key) do
    repo = Repo.repo()

    repo.transaction(fn ->
      lock_key = AdvisoryLock.key_to_lock_key(concurrency_key)

      case AdvisoryLock.lock(lock_key) do
        true ->
          check_limits(concurrency_key, config, :perform, repo, job_id)

        false ->
          {:error, :lock_failed}
      end
    end)
  end

  def check_perform_limit(nil, _job_id, _config) do
    {:ok, :ok}
  end

  defp check_limits(concurrency_key, config, type, repo, job_id \\ nil) do
    config = if is_map(config), do: Map.to_list(config), else: config

    limit = get_limit(config, type)
    throttle = get_throttle(config, type)
    has_enqueue_limit = has_enqueue_limit?(config)
    has_perform_limit = not is_nil(config[:perform_limit])

    cond do
      limit && check_limit_exceeded(concurrency_key, limit, type, repo, job_id, has_enqueue_limit, has_perform_limit) ->
        GoodJob.Telemetry.concurrency_limit_exceeded(concurrency_key, limit, type)
        {:error, :limit_exceeded}

      throttle && check_throttle_exceeded(concurrency_key, throttle, type, repo, job_id) ->
        GoodJob.Telemetry.concurrency_throttle_exceeded(concurrency_key, throttle, type)
        {:error, :throttle_exceeded}

      true ->
        :ok
    end
  end

  defp get_limit(config, :enqueue) do
    config[:enqueue_limit] || config[:total_limit]
  end

  defp get_limit(config, :perform) do
    config[:perform_limit] || config[:total_limit]
  end

  defp has_enqueue_limit?(config) do
    not is_nil(config[:enqueue_limit])
  end

  defp get_throttle(config, :enqueue) do
    config[:enqueue_throttle]
  end

  defp get_throttle(config, :perform) do
    config[:perform_throttle]
  end

  defp check_limit_exceeded(concurrency_key, limit, :enqueue, repo, _job_id, has_enqueue_limit, _has_perform_limit) do
    enqueue_concurrency =
      if has_enqueue_limit do
        repo.one(
          from(j in Job,
            where: j.concurrency_key == ^concurrency_key and is_nil(j.finished_at) and is_nil(j.locked_by_id),
            select: count(j.id)
          )
        )
      else
        repo.one(
          from(j in Job,
            where: j.concurrency_key == ^concurrency_key and is_nil(j.finished_at),
            select: count(j.id)
          )
        )
      end

    enqueue_concurrency + 1 > limit
  end

  defp check_limit_exceeded(concurrency_key, limit, :perform, repo, job_id, _has_enqueue_limit, has_perform_limit) do
    base_query =
      Job
      |> Job.unfinished()
      |> Job.with_concurrency_key(concurrency_key)

    performing_count =
      if has_perform_limit do
        base_query
        |> Job.locked()
        |> repo.aggregate(:count, :id)
      else
        base_query
        |> where([j], j.active_job_id != ^job_id)
        |> repo.aggregate(:count, :id)
      end

    performing_count >= limit
  end

  defp check_throttle_exceeded(concurrency_key, {throttle_limit, throttle_period}, :enqueue, repo, _job_id) do
    cutoff = DateTime.add(DateTime.utc_now(), -throttle_period, :second)

    enqueued_within_period =
      repo.one(
        from(j in Job,
          where: j.concurrency_key == ^concurrency_key and j.inserted_at >= ^cutoff,
          select: count(j.id)
        )
      )

    enqueued_within_period + 1 > throttle_limit
  end

  defp check_throttle_exceeded(concurrency_key, {throttle_limit, throttle_period}, :perform, repo, job_id) do
    cutoff = DateTime.add(DateTime.utc_now(), -throttle_period, :second)

    throttle_error_string =
      "GoodJob::ActiveJobExtensions::Concurrency::ThrottleExceededError: GoodJob::ActiveJobExtensions::Concurrency::ThrottleExceededError"

    base_query =
      from(e in Execution,
        join: j in Job,
        on: e.active_job_id == j.active_job_id,
        where: j.concurrency_key == ^concurrency_key and e.inserted_at >= ^cutoff
      )

    allowed_active_job_ids =
      repo.all(
        base_query
        |> where([e, j], is_nil(e.error) or e.error != ^throttle_error_string)
        |> order_by([e], asc: e.inserted_at)
        |> limit(^throttle_limit)
        |> select([e], e.active_job_id)
      )

    if allowed_active_job_ids == [] do
      false
    else
      job_id not in allowed_active_job_ids
    end
  end

  defmodule ConcurrencyExceededError do
    @moduledoc """
    Exception raised when concurrency limit is exceeded.
    """
    defexception message: "Concurrency limit exceeded"
  end

  defmodule ThrottleExceededError do
    @moduledoc """
    Exception raised when throttle limit is exceeded.
    """
    defexception message: "Throttle limit exceeded"
  end
end
