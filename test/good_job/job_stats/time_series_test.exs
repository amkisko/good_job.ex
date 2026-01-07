defmodule GoodJob.JobStats.TimeSeriesTest do
  use GoodJob.Testing.JobCase

  alias GoodJob.JobStats.TimeSeries
  alias GoodJob.{Job, Repo}

  setup do
    repo = Repo.repo()
    Ecto.Adapters.SQL.Sandbox.checkout(repo)
    Ecto.Adapters.SQL.Sandbox.mode(repo, {:shared, self()})
    :ok
  end

  test "activity_over_time returns aligned series" do
    {:ok, job1} =
      Job.enqueue(%{
        active_job_id: Ecto.UUID.generate(),
        job_class: "TestJob",
        queue_name: "default",
        serialized_params: %{"arguments" => []}
      })

    Repo.repo().update!(Job.changeset(job1, %{finished_at: DateTime.utc_now(), error: nil}))

    {:ok, job2} =
      Job.enqueue(%{
        active_job_id: Ecto.UUID.generate(),
        job_class: "TestJob",
        queue_name: "default",
        serialized_params: %{"arguments" => []}
      })

    Repo.repo().update!(Job.changeset(job2, %{finished_at: DateTime.utc_now(), error: "boom"}))

    result = TimeSeries.activity_over_time(1)

    assert length(result.labels) == length(result.created)
    assert length(result.created) == length(result.completed)
    assert length(result.completed) == length(result.failed)
    assert Enum.all?(result.created, &is_integer/1)
  end
end
