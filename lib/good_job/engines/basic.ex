defmodule GoodJob.Engines.Basic do
  @moduledoc """
  Basic engine for job execution.

  Provides the standard job execution engine with PostgreSQL backend.
  """

  alias GoodJob.{Config, Job, Repo}
  import Ecto.Query

  @doc """
  Inserts a job into the database.
  """
  @spec insert_job(Config.t(), Ecto.Changeset.t(), keyword()) :: {:ok, Job.t()} | {:error, term()}
  def insert_job(_config, changeset, _opts) do
    case Repo.repo().insert(changeset) do
      {:ok, job} -> {:ok, job}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc """
  Fetches available jobs for execution.
  """
  @spec fetch_jobs(Config.t(), keyword()) :: {:ok, [Job.t()]}
  def fetch_jobs(config, opts \\ []) do
    limit = Keyword.get(opts, :limit, config.max_processes)
    queue = Keyword.get(opts, :queue)

    # Unfinished jobs that are scheduled
    # Basic engine doesn't use queue filtering, so no parsed_queues needed
    query =
      Job
      |> Job.unfinished()
      |> Job.unlocked()
      |> where([j], is_nil(j.scheduled_at) or j.scheduled_at <= ^DateTime.utc_now())
      |> Job.order_for_candidate_lookup(%{})
      |> limit(^limit)

    query =
      if queue do
        Job.in_queue(query, queue)
      else
        query
      end

    jobs = Repo.repo().all(query)
    {:ok, jobs}
  end

  @doc """
  Marks a job as completed.
  """
  @spec complete_job(Config.t(), Job.t()) :: :ok
  def complete_job(_config, job) do
    now = DateTime.utc_now()

    job
    |> Job.changeset(%{
      performed_at: now,
      finished_at: now,
      error: nil
    })
    |> Repo.repo().update!()

    :ok
  end

  @doc """
  Marks a job as discarded.
  """
  @spec discard_job(Config.t(), Job.t()) :: :ok
  def discard_job(_config, job) do
    now = DateTime.utc_now()

    job
    |> Job.changeset(%{
      performed_at: now,
      finished_at: now,
      error: "Job discarded"
    })
    |> Repo.repo().update!()

    :ok
  end

  @doc """
  Marks a job for retry with error.
  """
  @spec error_job(Config.t(), Job.t(), integer()) :: :ok
  def error_job(_config, job, seconds) when is_integer(seconds) do
    scheduled_at = DateTime.add(DateTime.utc_now(), seconds, :second)

    # For retries: clear finished_at, set scheduled_at
    job
    |> Job.changeset(%{
      finished_at: nil,
      scheduled_at: scheduled_at,
      executions_count: (job.executions_count || 0) + 1
    })
    |> Repo.repo().update!()

    :ok
  end
end
