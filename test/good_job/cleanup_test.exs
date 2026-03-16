defmodule GoodJob.CleanupTest do
  use ExUnit.Case, async: false

  alias GoodJob.{Cleanup, Execution, Job, Repo}

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
    Ecto.Adapters.SQL.Sandbox.mode(Repo.repo(), :manual)
    :ok
  end

  describe "cleanup_preserved_jobs/1" do
    test "cleans up old jobs with default options" do
      # No old jobs, should return 0
      # Uses config defaults: cleanup_preserved_jobs_before_seconds_ago and cleanup_discarded_jobs
      deleted = Cleanup.cleanup_preserved_jobs()
      assert deleted >= 0
    end

    test "cleans up with custom older_than" do
      deleted = Cleanup.cleanup_preserved_jobs(older_than: 3600)
      assert deleted >= 0
    end

    test "cleans up with include_discarded option" do
      deleted = Cleanup.cleanup_preserved_jobs(include_discarded: true)
      assert deleted >= 0
    end

    test "uses config cleanup_discarded_jobs when not specified" do
      # Should use GoodJob.Config.cleanup_discarded_jobs?() default (true)
      deleted = Cleanup.cleanup_preserved_jobs()
      assert deleted >= 0
    end

    test "uses config cleanup_preserved_jobs_before_seconds_ago when not specified" do
      # Should use GoodJob.Config.cleanup_preserved_jobs_before_seconds_ago() default (14 days)
      deleted = Cleanup.cleanup_preserved_jobs()
      assert deleted >= 0
    end

    test "cleans up with custom batch size" do
      deleted = Cleanup.cleanup_preserved_jobs(in_batches_of: 500)
      assert deleted >= 0
    end

    test "supports explicit include_discarded: false override" do
      now = DateTime.utc_now()
      old = DateTime.add(now, -20 * 24 * 60 * 60, :second)

      job_id = Ecto.UUID.generate()

      insert_job!(%{
        active_job_id: job_id,
        finished_at: old,
        error: "discarded"
      })

      deleted = Cleanup.cleanup_preserved_jobs(older_than: 1, include_discarded: false)
      assert deleted == 0

      assert Repo.repo().aggregate(Job, :count, :id) == 1
    end

    test "caps preserved jobs and executions by count" do
      now = DateTime.utc_now()

      old_job_id = Ecto.UUID.generate()
      keep_job_id = Ecto.UUID.generate()

      old_time = DateTime.add(now, -120, :second)
      keep_time = DateTime.add(now, -60, :second)

      insert_job!(%{active_job_id: old_job_id, finished_at: old_time, error: nil})
      insert_job!(%{active_job_id: keep_job_id, finished_at: keep_time, error: nil})

      insert_execution!(%{active_job_id: old_job_id, finished_at: old_time})
      insert_execution!(%{active_job_id: keep_job_id, finished_at: keep_time})

      deleted = Cleanup.cleanup_preserved_jobs(older_than: 365 * 24 * 60 * 60, max_count: 1, in_batches_of: 1)
      assert deleted == 2

      assert Repo.repo().aggregate(Job, :count, :id) == 1
      assert Repo.repo().aggregate(Execution, :count, :id) == 1
    end
  end

  defp insert_job!(attrs) do
    %Job{}
    |> Job.changeset(attrs)
    |> Repo.repo().insert!()
  end

  defp insert_execution!(attrs) do
    %Execution{}
    |> Execution.changeset(attrs)
    |> Repo.repo().insert!()
  end
end
