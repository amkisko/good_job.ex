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

  defp check_limits(concurrency_key, config, type, repo, job_id \\ nil) do
    limit = get_limit(config, type)
    throttle = get_throttle(config, type)

    cond do
      limit && check_limit_exceeded(concurrency_key, limit, type, repo, job_id) ->
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

  defp get_throttle(config, :enqueue) do
    config[:enqueue_throttle]
  end

  defp get_throttle(config, :perform) do
    config[:perform_throttle]
  end

  defp check_limit_exceeded(concurrency_key, limit, :enqueue, repo, _job_id) do
    count =
      repo.one(
        from(j in Job,
          where: j.concurrency_key == ^concurrency_key and is_nil(j.finished_at) and is_nil(j.locked_by_id),
          select: count(j.id)
        )
      )

    count + 1 > limit
  end

  defp check_limit_exceeded(concurrency_key, limit, :perform, repo, _job_id) do
    # Count currently locked jobs for this concurrency key
    count =
      repo.one(
        from(j in Job,
          where: j.concurrency_key == ^concurrency_key and is_nil(j.finished_at) and not is_nil(j.locked_by_id),
          select: count(j.id)
        )
      )

    # Check if adding this job would exceed the limit
    count >= limit
  end

  defp check_throttle_exceeded(concurrency_key, {throttle_limit, throttle_period}, :enqueue, repo, _job_id) do
    cutoff = DateTime.add(DateTime.utc_now(), -throttle_period, :second)

    count =
      repo.one(
        from(j in Job,
          where: j.concurrency_key == ^concurrency_key and j.inserted_at >= ^cutoff,
          select: count(j.id)
        )
      )

    count + 1 > throttle_limit
  end

  defp check_throttle_exceeded(concurrency_key, {throttle_limit, throttle_period}, :perform, repo, job_id) do
    cutoff = DateTime.add(DateTime.utc_now(), -throttle_period, :second)

    # Get allowed job IDs from executions
    allowed_ids =
      repo.all(
        from(e in Execution,
          join: j in Job,
          on: e.active_job_id == j.active_job_id,
          where:
            j.concurrency_key == ^concurrency_key and e.inserted_at >= ^cutoff and
              (is_nil(e.error) or e.error != "GoodJob.Concurrency.ThrottleExceededError"),
          order_by: [asc: e.inserted_at],
          limit: ^throttle_limit,
          select: e.active_job_id
        )
      )

    job_id not in allowed_ids
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
