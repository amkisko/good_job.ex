defmodule GoodJob.Job.State do
  @moduledoc """
  Job state calculation logic.

  Calculates job state from timestamp fields.
  """

  @doc """
  Calculates the job state from timestamp fields.
  Returns :available, :running, :succeeded, :discarded, :scheduled, or :retried

  Optimized version that accepts optional current_time to avoid repeated DateTime.utc_now() calls.
  """
  @spec calculate(GoodJob.Job.t(), DateTime.t() | nil) :: atom()
  def calculate(job, current_time \\ nil) do
    now = current_time || DateTime.utc_now()

    cond do
      not is_nil(job.finished_at) ->
        if is_nil(job.error), do: :succeeded, else: :discarded

      not is_nil(job.performed_at) ->
        :running

      not is_nil(job.retried_good_job_id) ->
        :retried

      not is_nil(job.scheduled_at) ->
        case DateTime.compare(job.scheduled_at, now) do
          :gt -> :scheduled
          _ -> :available
        end

      true ->
        :available
    end
  end
end
