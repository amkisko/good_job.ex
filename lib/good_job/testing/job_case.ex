defmodule GoodJob.Testing.JobCase do
  @moduledoc """
  Test case template for job-related tests.

  Extends `GoodJob.Testing.RepoCase` with job-specific helpers.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      use GoodJob.Testing.RepoCase

      import GoodJob.Testing.JobCase
      import Ecto.Query

      alias GoodJob.{Job, Repo}
    end
  end

  @doc """
  Creates a job with the given attributes.

  ## Examples

      job = create_job(%{job_class: "MyApp.MyJob", queue_name: "high"})
  """
  def create_job(attrs \\ %{}) do
    alias GoodJob.Job

    defaults = %{
      active_job_id: Ecto.UUID.generate(),
      job_class: "TestJob",
      queue_name: "default",
      priority: 0,
      serialized_params: %{"arguments" => %{}},
      executions_count: 0
    }

    attrs = Map.merge(defaults, attrs)
    repo = GoodJob.Config.repo()

    %Job{}
    |> Job.changeset(attrs)
    |> repo.insert!()
  end
end
