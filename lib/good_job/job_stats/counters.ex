defmodule GoodJob.JobStats.Counters do
  @moduledoc """
  Job counting functions for statistics.
  """

  import Ecto.Query
  alias GoodJob.{Job, Repo}

  @doc """
  Returns the count of queued jobs (unfinished, not performed, scheduled time passed).
  """
  @spec count_queued(Ecto.Query.t() | module()) :: integer()
  def count_queued(query) do
    query
    |> Job.queued()
    |> Repo.repo().aggregate(:count, :id)
  end

  @doc """
  Returns the count of running jobs (performed but not finished).
  """
  @spec count_running(Ecto.Query.t() | module()) :: integer()
  def count_running(query) do
    query
    |> Job.running()
    |> Repo.repo().aggregate(:count, :id)
  end

  @doc """
  Returns the count of succeeded jobs (finished without error).
  """
  @spec count_succeeded(Ecto.Query.t() | module()) :: integer()
  def count_succeeded(query) do
    query
    |> Job.succeeded()
    |> Repo.repo().aggregate(:count, :id)
  end

  @doc """
  Returns the count of discarded jobs (finished with error).
  """
  @spec count_discarded(Ecto.Query.t() | module()) :: integer()
  def count_discarded(query) do
    query
    |> Job.discarded()
    |> Repo.repo().aggregate(:count, :id)
  end

  @doc """
  Returns the total count of jobs.
  """
  @spec count_all(Ecto.Query.t() | module()) :: integer()
  def count_all(query) do
    Repo.repo().aggregate(query, :count, :id)
  end

  @doc """
  Returns the count of jobs with errors.
  """
  @spec count_with_errors(Ecto.Query.t() | module()) :: integer()
  def count_with_errors(query) do
    query
    |> where([j], not is_nil(j.error))
    |> Repo.repo().aggregate(:count, :id)
  end

  @doc """
  Returns the oldest job (by created_at).
  """
  @spec oldest_job(Ecto.Query.t() | module()) :: GoodJob.Job.t() | nil
  def oldest_job(query) do
    query
    |> order_by([j], asc: j.inserted_at)
    |> limit(1)
    |> Repo.repo().one()
  end

  @doc """
  Returns the newest job (by created_at).
  """
  @spec newest_job(Ecto.Query.t() | module()) :: GoodJob.Job.t() | nil
  def newest_job(query) do
    query
    |> order_by([j], desc: j.inserted_at)
    |> limit(1)
    |> Repo.repo().one()
  end
end
