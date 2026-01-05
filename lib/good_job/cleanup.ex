defmodule GoodJob.Cleanup do
  @moduledoc """
  Handles cleanup of preserved job records.
  """

  alias GoodJob.{BatchRecord, Execution, Job, Repo}
  import Ecto.Query

  @doc """
  Cleans up preserved job records older than the specified time.
  """
  def cleanup_preserved_jobs(opts \\ []) do
    alias GoodJob.Telemetry

    older_than =
      Keyword.get(opts, :older_than) ||
        GoodJob.Config.cleanup_preserved_jobs_before_seconds_ago()

    include_discarded =
      Keyword.get(opts, :include_discarded) ||
        GoodJob.Config.cleanup_discarded_jobs?()

    in_batches_of = Keyword.get(opts, :in_batches_of, 1_000)

    repo = Repo.repo()
    cutoff = DateTime.add(DateTime.utc_now(), -older_than, :second)

    deleted_jobs = cleanup_jobs(repo, cutoff, include_discarded, in_batches_of)
    deleted_batches = cleanup_batches(repo, cutoff, include_discarded, in_batches_of)
    deleted_executions = cleanup_executions(repo, cutoff, in_batches_of)

    total_deleted = deleted_jobs + deleted_batches + deleted_executions

    Telemetry.cleanup_preserved_jobs(total_deleted, opts)

    total_deleted
  end

  defp cleanup_jobs(repo, cutoff, include_discarded, batch_size) do
    query =
      Job
      |> Job.finished_before(cutoff)
      |> order_by([j], asc: j.finished_at)
      |> limit(^batch_size)

    query = if include_discarded, do: query, else: where(query, [j], is_nil(j.error))

    total_deleted = 0

    Stream.iterate(0, &(&1 + 1))
    |> Enum.reduce_while(total_deleted, fn _iteration, acc ->
      job_ids = repo.all(select(query, [j], j.active_job_id))

      if Enum.empty?(job_ids) do
        {:halt, acc}
      else
        deleted_executions =
          from(e in Execution, where: e.active_job_id in ^job_ids)
          |> repo.delete_all()
          |> elem(0)

        deleted_jobs =
          from(j in Job, where: j.active_job_id in ^job_ids)
          |> repo.delete_all()
          |> elem(0)

        {:cont, acc + deleted_jobs + deleted_executions}
      end
    end)
  end

  defp cleanup_batches(repo, cutoff, include_discarded, batch_size) do
    base_query =
      BatchRecord
      |> BatchRecord.finished_before(cutoff)

    base_query = if include_discarded, do: base_query, else: where(base_query, [b], is_nil(b.discarded_at))

    total_deleted = 0

    Stream.iterate(0, &(&1 + 1))
    |> Enum.reduce_while(total_deleted, fn _iteration, acc ->
      ids_query =
        base_query
        |> select([b], b.id)
        |> limit(^batch_size)

      ids = repo.all(ids_query)

      if Enum.empty?(ids) do
        {:halt, acc}
      else
        deleted =
          from(b in BatchRecord, where: b.id in ^ids)
          |> repo.delete_all()
          |> elem(0)

        {:cont, acc + deleted}
      end
    end)
  end

  defp cleanup_executions(repo, cutoff, batch_size) do
    base_query = from(e in Execution, where: e.finished_at <= ^cutoff)

    total_deleted = 0

    Stream.iterate(0, &(&1 + 1))
    |> Enum.reduce_while(total_deleted, fn _iteration, acc ->
      ids_query =
        base_query
        |> select([e], e.id)
        |> limit(^batch_size)

      ids = repo.all(ids_query)

      if Enum.empty?(ids) do
        {:halt, acc}
      else
        deleted =
          from(e in Execution, where: e.id in ^ids)
          |> repo.delete_all()
          |> elem(0)

        {:cont, acc + deleted}
      end
    end)
  end
end
