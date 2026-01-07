defmodule GoodJob.Job.Query do
  @moduledoc """
  Query scopes and filtering functions for GoodJob.Job.

  Provides Ecto query helpers for filtering and ordering jobs.
  """

  import Ecto.Query
  alias GoodJob.Job

  @doc """
  Returns a query for unfinished jobs (jobs without finished_at).
  """
  @spec unfinished(Ecto.Query.t() | module()) :: Ecto.Query.t()
  def unfinished(query \\ Job) do
    where(query, [j], is_nil(j.finished_at))
  end

  @doc """
  Returns a query for finished jobs.
  """
  @spec finished(Ecto.Query.t() | module()) :: Ecto.Query.t()
  def finished(query \\ Job) do
    where(query, [j], not is_nil(j.finished_at))
  end

  @doc """
  Returns a query for unlocked jobs (using locked_by_id as proxy).
  """
  @spec unlocked(Ecto.Query.t() | module()) :: Ecto.Query.t()
  def unlocked(query \\ Job) do
    where(query, [j], is_nil(j.locked_by_id))
  end

  @doc """
  Returns a query for locked jobs (using locked_by_id as proxy).
  """
  @spec locked(Ecto.Query.t() | module()) :: Ecto.Query.t()
  def locked(query \\ Job) do
    where(query, [j], not is_nil(j.locked_by_id))
  end

  @doc """
  Joins with pg_locks to check advisory locks on jobs.
  """
  @spec joins_advisory_locks(Ecto.Query.t() | module()) :: Ecto.Query.t()
  def joins_advisory_locks(query \\ Job) do
    table_name = "good_jobs"

    from(j in query,
      left_join:
        l in fragment("""
        pg_locks
        """),
      on:
        fragment(
          """
          ?.locktype = 'advisory'
            AND ?.objsubid = 1
            AND ?.classid = ('x' || substr(md5(? || '-' || ?::text), 1, 16))::bit(32)::int
            AND ?.objid = (('x' || substr(md5(? || '-' || ?::text), 1, 16))::bit(64) << 32)::bit(32)::int
          """,
          l,
          l,
          l,
          ^table_name,
          fragment("?::text", j.id),
          l,
          ^table_name,
          fragment("?::text", j.id)
        )
    )
  end

  @doc """
  Returns a query for jobs that are advisory unlocked (no advisory lock in pg_locks).
  """
  @spec advisory_unlocked(Ecto.Query.t() | module()) :: Ecto.Query.t()
  def advisory_unlocked(query \\ Job) do
    query
    |> joins_advisory_locks()
    |> where([j, l], is_nil(l.locktype))
  end

  @doc """
  Returns a query for jobs that are advisory locked (have advisory lock in pg_locks).
  """
  @spec advisory_locked(Ecto.Query.t() | module()) :: Ecto.Query.t()
  def advisory_locked(query \\ Job) do
    query
    |> joins_advisory_locks()
    |> where([j, l], not is_nil(l.locktype))
  end

  @doc """
  Returns a query for jobs in a specific queue.
  """
  @spec in_queue(Ecto.Query.t() | module(), String.t()) :: Ecto.Query.t()
  def in_queue(query \\ Job, queue_name) do
    where(query, [j], j.queue_name == ^queue_name)
  end

  @doc """
  Returns a query for jobs scheduled before a specific time.
  """
  @spec scheduled_before(Ecto.Query.t() | module(), DateTime.t()) :: Ecto.Query.t()
  def scheduled_before(query \\ Job, datetime) do
    where(query, [j], j.scheduled_at <= ^datetime)
  end

  @doc """
  Returns a query for jobs finished before a specific time.
  """
  @spec finished_before(Ecto.Query.t() | module(), DateTime.t()) :: Ecto.Query.t()
  def finished_before(query \\ Job, datetime) do
    where(query, [j], j.finished_at <= ^datetime)
  end

  @doc """
  Returns a query for jobs with a specific concurrency key.
  """
  @spec with_concurrency_key(Ecto.Query.t() | module(), String.t()) :: Ecto.Query.t()
  def with_concurrency_key(query \\ Job, key) do
    where(query, [j], j.concurrency_key == ^key)
  end

  @doc """
  Orders jobs by priority and inserted_at for candidate lookup.

  If parsed_queues contains :ordered_queues, orders by queue order first.
  """
  def order_for_candidate_lookup(query \\ Job, parsed_queues \\ %{}) do
    query =
      if parsed_queues[:ordered_queues] && parsed_queues[:include] do
        queue_ordered(query, parsed_queues[:include])
      else
        query
      end

    order_by(query, [j],
      asc_nulls_last: j.priority,
      asc: j.inserted_at
    )
  end

  @doc """
  Orders jobs by queue order (respects the order of queues in the list).
  """
  @spec queue_ordered(Ecto.Query.t() | module(), [String.t()]) :: Ecto.Query.t()
  def queue_ordered(query \\ Job, queues) when is_list(queues) do
    case_clauses =
      queues
      |> Enum.with_index()
      |> Enum.map_join(" ", fn {queue_name, index} ->
        "WHEN queue_name = '#{String.replace(queue_name, "'", "''")}' THEN #{index}"
      end)

    case_sql = "(CASE #{case_clauses} ELSE #{length(queues)} END)"

    order_by(query, [j], asc: fragment(^case_sql))
  end

  @doc """
  Returns a query for jobs in a specific batch.
  """
  @spec in_batch(Ecto.Query.t() | module(), String.t()) :: Ecto.Query.t()
  def in_batch(query \\ Job, batch_id) do
    where(query, [j], j.batch_id == ^batch_id)
  end

  @doc """
  Returns a query for running jobs (performed but not finished).
  """
  @spec running(Ecto.Query.t() | module()) :: Ecto.Query.t()
  def running(query \\ Job) do
    where(query, [j], not is_nil(j.performed_at) and is_nil(j.finished_at))
  end

  @doc """
  Returns a query for queued jobs (not performed, not finished, scheduled time has passed).
  """
  @spec queued(Ecto.Query.t() | module()) :: Ecto.Query.t()
  def queued(query \\ Job) do
    now = DateTime.utc_now()

    where(
      query,
      [j],
      is_nil(j.performed_at) and
        is_nil(j.finished_at) and
        (is_nil(j.scheduled_at) or j.scheduled_at <= ^now)
    )
  end

  @doc """
  Returns a query for succeeded jobs (finished without error).
  """
  @spec succeeded(Ecto.Query.t() | module()) :: Ecto.Query.t()
  def succeeded(query \\ Job) do
    finished(query) |> where([j], is_nil(j.error))
  end

  @doc """
  Returns a query for discarded jobs (finished with error).
  """
  @spec discarded(Ecto.Query.t() | module()) :: Ecto.Query.t()
  def discarded(query \\ Job) do
    finished(query) |> where([j], not is_nil(j.error))
  end

  @doc """
  Returns a query for scheduled jobs (not performed, not finished, scheduled time is in the future).
  """
  @spec scheduled(Ecto.Query.t() | module()) :: Ecto.Query.t()
  def scheduled(query \\ Job) do
    now = DateTime.utc_now()

    where(
      query,
      [j],
      is_nil(j.performed_at) and
        is_nil(j.finished_at) and
        not is_nil(j.scheduled_at) and
        j.scheduled_at > ^now
    )
  end

  @doc """
  Returns a query for jobs with a specific label.
  """
  def with_label(query \\ Job, label) do
    where(query, [j], ^label in j.labels)
  end

  @doc """
  Returns a query for jobs with any of the given labels.
  """
  def with_any_label(query \\ Job, labels) when is_list(labels) do
    where(query, [j], fragment("? && ?", j.labels, ^labels))
  end

  @doc """
  Returns a query for jobs with all of the given labels.
  """
  def with_all_labels(query \\ Job, labels) when is_list(labels) do
    where(query, [j], fragment("? @> ?", j.labels, ^labels))
  end

  @doc """
  Returns a query for jobs with any of the given labels (alias for with_any_label).
  """
  def with_labels(query \\ Job, labels) when is_list(labels) do
    with_any_label(query, labels)
  end

  @doc """
  Orders jobs for dequeueing (priority DESC NULLS LAST, created_at ASC).
  """
  def dequeueing_ordered(query \\ Job) do
    order_by(query, [j],
      desc: fragment("? NULLS LAST", j.priority),
      asc: j.inserted_at
    )
  end

  @doc """
  Returns a query for only scheduled jobs (with scheduled_at set).
  """
  def only_scheduled(query \\ Job) do
    where(query, [j], not is_nil(j.scheduled_at))
  end

  @doc """
  Excludes paused queues (placeholder for future implementation).
  """
  def exclude_paused(query \\ Job) do
    case query do
      %Ecto.Query{} -> query
      _ -> from(j in Job)
    end
  end

  @doc """
  Returns a query for jobs with a specific job class.
  """
  def with_job_class(query \\ Job, job_class) when is_binary(job_class) do
    where(query, [j], j.job_class == ^job_class)
  end

  @doc """
  Returns a query for jobs with a specific batch_id.
  """
  def with_batch_id(query \\ Job, batch_id) do
    where(query, [j], j.batch_id == ^batch_id)
  end

  @doc """
  Returns a query for jobs created after a specific time.
  """
  def created_after(query \\ Job, datetime) do
    where(query, [j], j.inserted_at >= ^datetime)
  end

  @doc """
  Returns a query for jobs created before a specific time.
  """
  def created_before(query \\ Job, datetime) do
    where(query, [j], j.inserted_at <= ^datetime)
  end

  @doc """
  Returns a query for jobs with a specific priority.
  """
  def with_priority(query \\ Job, priority) when is_integer(priority) do
    where(query, [j], j.priority == ^priority)
  end

  @doc """
  Returns a query for jobs with minimum priority.
  """
  def with_min_priority(query \\ Job, min_priority) when is_integer(min_priority) do
    where(query, [j], j.priority >= ^min_priority)
  end

  @doc """
  Returns a query for jobs with maximum priority.
  """
  def with_max_priority(query \\ Job, max_priority) when is_integer(max_priority) do
    where(query, [j], j.priority <= ^max_priority)
  end

  @doc """
  Returns a query for jobs with errors.
  """
  def with_errors(query \\ Job) do
    where(query, [j], not is_nil(j.error))
  end

  @doc """
  Returns a query for jobs without errors.
  """
  def without_errors(query \\ Job) do
    where(query, [j], is_nil(j.error))
  end

  @doc """
  Returns a query for jobs with a specific cron_key.
  """
  def with_cron_key(query \\ Job, cron_key) when is_binary(cron_key) do
    where(query, [j], j.cron_key == ^cron_key)
  end

  @doc """
  Orders jobs by creation time (newest first).
  """
  def order_by_created_desc(query \\ Job) do
    order_by(query, [j], desc: j.inserted_at)
  end

  @doc """
  Orders jobs by creation time (oldest first).
  """
  def order_by_created_asc(query \\ Job) do
    order_by(query, [j], asc: j.inserted_at)
  end

  @doc """
  Orders jobs by scheduled time (earliest first).
  """
  def order_by_scheduled_asc(query \\ Job) do
    order_by(query, [j], asc_nulls_last: j.scheduled_at)
  end

  @doc """
  Orders jobs by finished time (newest first).
  """
  def order_by_finished_desc(query \\ Job) do
    order_by(query, [j], desc_nulls_last: j.finished_at)
  end
end
