defmodule GoodJob.JobStats do
  @moduledoc """
  Provides statistics and metrics for jobs.
  """

  alias GoodJob.{Job, JobStats.Aggregation, JobStats.Counters, JobStats.TimeSeries}

  @doc """
  Returns job statistics for all queues.
  """
  @spec stats() :: map()
  def stats do
    base_query = Job
    build_stats(base_query)
  end

  @doc """
  Returns job statistics for a specific queue.
  """
  @spec stats(String.t()) :: map()
  def stats(queue_name) when is_binary(queue_name) do
    base_query = Job.in_queue(Job, queue_name)
    build_stats(base_query)
  end

  @spec build_stats(Ecto.Query.t() | module()) :: map()
  defp build_stats(base_query) do
    %{
      total: Counters.count_all(base_query),
      queued: Counters.count_queued(base_query),
      running: Counters.count_running(base_query),
      succeeded: Counters.count_succeeded(base_query),
      discarded: Counters.count_discarded(base_query),
      with_errors: Counters.count_with_errors(base_query),
      oldest_job: Counters.oldest_job(base_query),
      newest_job: Counters.newest_job(base_query)
    }
  end

  @doc """
  Returns the count of queued jobs (unfinished, not performed, scheduled time passed).
  """
  @spec count_queued(Ecto.Query.t()) :: integer()
  defdelegate count_queued(query), to: Counters

  @doc """
  Returns the count of running jobs (performed but not finished).
  """
  @spec count_running(Ecto.Query.t()) :: integer()
  defdelegate count_running(query), to: Counters

  @doc """
  Returns the count of succeeded jobs (finished without error).
  """
  @spec count_succeeded(Ecto.Query.t()) :: integer()
  defdelegate count_succeeded(query), to: Counters

  @doc """
  Returns the count of discarded jobs (finished with error).
  """
  @spec count_discarded(Ecto.Query.t()) :: integer()
  defdelegate count_discarded(query), to: Counters

  @doc """
  Returns the total count of jobs.
  """
  @spec count_all(Ecto.Query.t()) :: integer()
  defdelegate count_all(query), to: Counters

  @doc """
  Returns the count of jobs with errors.
  """
  @spec count_with_errors(Ecto.Query.t()) :: integer()
  defdelegate count_with_errors(query), to: Counters

  @doc """
  Returns the oldest job (by created_at).
  """
  @spec oldest_job(Ecto.Query.t()) :: GoodJob.Job.t() | nil
  defdelegate oldest_job(query), to: Counters

  @doc """
  Returns the newest job (by created_at).
  """
  @spec newest_job(Ecto.Query.t()) :: GoodJob.Job.t() | nil
  defdelegate newest_job(query), to: Counters

  @doc """
  Returns queue statistics for all queues.
  """
  @spec queue_stats() :: map()
  defdelegate queue_stats(), to: Aggregation

  @doc """
  Returns job class statistics.
  """
  @spec job_class_stats() :: map()
  defdelegate job_class_stats(), to: Aggregation

  @doc """
  Returns average execution time for completed jobs across all queues.
  """
  @spec average_execution_time() :: float() | nil
  def average_execution_time do
    Aggregation.average_execution_time(Job)
  end

  @doc """
  Returns average execution time for completed jobs in a specific queue.
  """
  @spec average_execution_time(String.t()) :: float() | nil
  def average_execution_time(queue_name) when is_binary(queue_name) do
    query = Job.in_queue(Job, queue_name)
    Aggregation.average_execution_time(query)
  end

  @doc """
  Returns job activity data over time for charting.
  Groups jobs by hour for the last N hours showing created, completed, and failed counts.
  """
  @spec activity_over_time(hours :: integer()) :: map()
  defdelegate activity_over_time(hours), to: TimeSeries
end
