defmodule GoodJob.Testing.Helpers do
  @moduledoc """
  Helper functions for testing jobs.

  Provides utilities for performing jobs in tests.
  """

  alias GoodJob.{Job, Repo}

  @doc """
  Performs all enqueued jobs inline (for testing).

  ## Examples

      perform_jobs()
      perform_jobs(MyApp.MyJob)
  """
  def perform_jobs(job_module \\ nil) do
    query =
      if job_module do
        Job.queued()
        |> Job.with_job_class(to_string(job_module))
      else
        Job.queued()
      end

    jobs = Repo.repo().all(query)

    Enum.each(jobs, fn job ->
      GoodJob.JobExecutor.execute_inline(job)
    end)

    length(jobs)
  end
end
