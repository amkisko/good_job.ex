defmodule GoodJob.JobStats.Aggregation do
  @moduledoc """
  Aggregation functions for job statistics.
  """

  import Ecto.Query
  alias GoodJob.{Job, Repo}

  @doc """
  Returns queue statistics for all queues.
  """
  @spec queue_stats() :: map()
  def queue_stats do
    query =
      from(j in Job,
        select: {j.queue_name, count(j.id)},
        group_by: j.queue_name
      )

    Repo.repo().all(query)
    |> Enum.into(%{}, fn {queue_name, count} -> {queue_name, count} end)
  end

  @doc """
  Returns job class statistics.
  """
  @spec job_class_stats() :: map()
  def job_class_stats do
    query =
      from(j in Job,
        select: {j.job_class, count(j.id)},
        group_by: j.job_class
      )

    Repo.repo().all(query)
    |> Enum.into(%{}, fn {job_class, count} -> {job_class, count} end)
  end

  @doc """
  Returns average execution time for completed jobs.
  """
  @spec average_execution_time(Ecto.Query.t() | module()) :: float() | nil
  def average_execution_time(query) do
    query =
      from(j in query,
        where: not is_nil(j.performed_at) and not is_nil(j.finished_at),
        select: avg(fragment("EXTRACT(EPOCH FROM (? - ?))", j.finished_at, j.performed_at))
      )

    case Repo.repo().one(query) do
      nil -> nil
      value when is_struct(value, Decimal) -> Decimal.to_float(value)
      value -> value
    end
  end
end
