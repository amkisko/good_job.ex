defmodule GoodJob.Concurrency do
  @moduledoc """
  Concurrency control for jobs.

  Limits and throttles can be scoped by `concurrency_key` (legacy, shared with
  Ruby GoodJob before v5) or by a job `label` (preferred; claim key `label:<name>`).

  When `good_job_concurrency_claims` exists, perform limits grant/wait/promote
  through `GoodJob.ConcurrencyClaim`.
  """

  require Logger
  import Ecto.Query

  alias GoodJob.{AdvisoryLock, ConcurrencyClaim, Execution, Job, Repo}

  @doc """
  Checks if a job can be enqueued based on concurrency limits.

  Returns `{:ok, :ok}` if allowed.

  If the limit or throttle is exceeded, or the advisory lock could not be taken, the result is
  `{:ok, {:error, reason}}` where `reason` is `:limit_exceeded`, `:throttle_exceeded`, or
  `:lock_failed`.
  """
  def check_enqueue_limit(concurrency_key, config) when is_binary(concurrency_key) do
    check_enqueue_limit(concurrency_key, config, [])
  end

  def check_enqueue_limit(nil, _config), do: {:ok, :ok}

  def check_enqueue_limit(concurrency_key, config, opts)
      when is_binary(concurrency_key) and is_list(opts) do
    config = normalize_config(config)
    maybe_warn_key_only(config)

    with_advisory_lock(lock_name(config, concurrency_key), fn ->
      check_limits(scope_for(config, concurrency_key), config, :enqueue, Repo.repo(), nil, opts)
    end)
  end

  @doc """
  Checks if a job can be performed based on concurrency limits.

  `opts` may include `:job_id` (good_jobs row id), `:locked_by_id`, and `:labels`.
  """
  def check_perform_limit(concurrency_key, active_job_id, config) when is_binary(concurrency_key) do
    check_perform_limit(concurrency_key, active_job_id, config, [])
  end

  def check_perform_limit(nil, _active_job_id, _config), do: {:ok, :ok}

  def check_perform_limit(concurrency_key, active_job_id, config, opts)
      when is_binary(concurrency_key) and is_list(opts) do
    config = normalize_config(config)
    maybe_warn_key_only(config)
    opts = Keyword.put_new(opts, :concurrency_key, concurrency_key)

    with_advisory_lock(lock_name(config, concurrency_key), fn ->
      check_limits(scope_for(config, concurrency_key), config, :perform, Repo.repo(), active_job_id, opts)
    end)
  end

  @doc """
  Label-scoped enqueue check (preferred path toward Ruby GoodJob v5).
  """
  def check_enqueue_limit_for_label(label, config) when is_binary(label) do
    config = normalize_config(config) |> Keyword.put(:label, label)

    with_advisory_lock(ConcurrencyClaim.claim_key_for_label(label), fn ->
      check_limits(Job.with_label(label), config, :enqueue, Repo.repo(), nil, [])
    end)
  end

  @doc """
  Label-scoped perform check with optional claims grant/wait.
  """
  def check_perform_limit_for_label(label, active_job_id, config, opts \\ [])
      when is_binary(label) do
    config = normalize_config(config) |> Keyword.put(:label, label)

    with_advisory_lock(ConcurrencyClaim.claim_key_for_label(label), fn ->
      check_limits(Job.with_label(label), config, :perform, Repo.repo(), active_job_id, opts)
    end)
  end

  defp with_advisory_lock(lock_name, fun) do
    repo = Repo.repo()

    repo.transaction(fn ->
      lock_key = AdvisoryLock.key_to_lock_key(lock_name)

      case AdvisoryLock.lock(lock_key) do
        true -> fun.()
        false -> {:error, :lock_failed}
      end
    end)
  end

  defp check_limits(scope, config, type, repo, active_job_id, opts) do
    limit = get_limit(config, type)
    throttle = get_throttle(config, type)
    has_enqueue_limit = not is_nil(config[:enqueue_limit])
    has_perform_limit = not is_nil(config[:perform_limit])

    cond do
      limit &&
          perform_limit_exceeded?(
            scope,
            limit,
            type,
            repo,
            active_job_id,
            has_enqueue_limit,
            has_perform_limit,
            config,
            opts
          ) ->
        GoodJob.Telemetry.concurrency_limit_exceeded(scope_name(config, opts), limit, type)
        {:error, :limit_exceeded}

      throttle && check_throttle_exceeded(scope, throttle, type, repo, active_job_id) ->
        GoodJob.Telemetry.concurrency_throttle_exceeded(scope_name(config, opts), throttle, type)
        {:error, :throttle_exceeded}

      true ->
        :ok
    end
  end

  defp perform_limit_exceeded?(
         scope,
         limit,
         :enqueue,
         repo,
         _active_job_id,
         has_enqueue_limit,
         _has_perform_limit,
         _config,
         _opts
       ) do
    count =
      if has_enqueue_limit do
        scope
        |> where([j], is_nil(j.finished_at) and is_nil(j.locked_by_id))
        |> repo.aggregate(:count, :id)
      else
        scope
        |> where([j], is_nil(j.finished_at))
        |> repo.aggregate(:count, :id)
      end

    count + 1 > limit
  end

  defp perform_limit_exceeded?(
         scope,
         limit,
         :perform,
         repo,
         active_job_id,
         _has_enqueue_limit,
         has_perform_limit,
         config,
         opts
       ) do
    job_row_id = Keyword.get(opts, :job_id)
    locked_by_id = Keyword.get(opts, :locked_by_id)

    cond do
      is_binary(job_row_id) and ConcurrencyClaim.table_exists?() ->
        claim_key = claim_key(config, opts)

        not ConcurrencyClaim.claim(
          key: claim_key,
          limit: limit,
          scope: scope,
          job_id: job_row_id,
          locked_by_id: locked_by_id
        )

      has_perform_limit ->
        scope
        |> Job.locked()
        |> repo.aggregate(:count, :id) >= limit

      true ->
        scope
        |> where([j], j.active_job_id != ^active_job_id)
        |> where([j], is_nil(j.finished_at))
        |> repo.aggregate(:count, :id) >= limit
    end
  end

  defp check_throttle_exceeded(scope, {throttle_limit, throttle_period}, :enqueue, repo, _active_job_id) do
    cutoff = DateTime.add(DateTime.utc_now(), -throttle_period, :second)

    count =
      scope
      |> where([j], j.inserted_at >= ^cutoff)
      |> repo.aggregate(:count, :id)

    count + 1 > throttle_limit
  end

  defp check_throttle_exceeded(scope, {throttle_limit, throttle_period}, :perform, repo, active_job_id) do
    cutoff = DateTime.add(DateTime.utc_now(), -throttle_period, :second)

    throttle_error_string =
      "GoodJob::ActiveJobExtensions::Concurrency::ThrottleExceededError: GoodJob::ActiveJobExtensions::Concurrency::ThrottleExceededError"

    scoped_active_job_ids = repo.all(from(j in scope, select: j.active_job_id))

    allowed_active_job_ids =
      if scoped_active_job_ids == [] do
        []
      else
        repo.all(
          from(e in Execution,
            where: e.active_job_id in ^scoped_active_job_ids,
            where: e.inserted_at >= ^cutoff,
            where: is_nil(e.error) or e.error != ^throttle_error_string,
            order_by: [asc: e.inserted_at],
            limit: ^throttle_limit,
            select: e.active_job_id
          )
        )
      end

    allowed_active_job_ids != [] and active_job_id not in allowed_active_job_ids
  end

  defp get_limit(config, :enqueue), do: config[:enqueue_limit] || config[:total_limit]
  defp get_limit(config, :perform), do: config[:perform_limit] || config[:total_limit]

  defp get_throttle(config, :enqueue), do: config[:enqueue_throttle]
  defp get_throttle(config, :perform), do: config[:perform_throttle]

  defp normalize_config(config) when is_map(config), do: Map.to_list(config)
  defp normalize_config(config) when is_list(config), do: config
  defp normalize_config(_), do: []

  defp scope_for(config, concurrency_key) do
    case config[:label] do
      label when is_binary(label) and label != "" -> Job.with_label(label)
      _ -> Job.with_concurrency_key(concurrency_key)
    end
  end

  defp lock_name(config, concurrency_key) do
    case config[:label] do
      label when is_binary(label) and label != "" -> ConcurrencyClaim.claim_key_for_label(label)
      _ -> concurrency_key
    end
  end

  defp claim_key(config, opts) do
    case config[:label] do
      label when is_binary(label) and label != "" ->
        ConcurrencyClaim.claim_key_for_label(label)

      _ ->
        key = Keyword.get(opts, :concurrency_key) || config[:concurrency_key] || "all"
        ConcurrencyClaim.claim_key_for_concurrency_key(key)
    end
  end

  defp scope_name(config, opts) do
    config[:label] || Keyword.get(opts, :concurrency_key) || "concurrency"
  end

  defp maybe_warn_key_only(config) do
    label = config[:label]

    if is_nil(label) or label == "" do
      case :persistent_term.get({__MODULE__, :key_only_warned}, false) do
        true ->
          :ok

        false ->
          :persistent_term.put({__MODULE__, :key_only_warned}, true)

          Logger.warning("""
          GoodJob concurrency_key limits are deprecated toward Ruby GoodJob v5 / Elixir 2.0. \
          Prefer labels: set job labels and concurrency_config: [label: "...", perform_limit: n]. \
          See COMPATIBILITY.md.
          """)
      end
    else
      :ok
    end
  end
end
