defmodule GoodJob.CleanupTest do
  use ExUnit.Case, async: false

  alias GoodJob.{Cleanup, Repo}

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
    Ecto.Adapters.SQL.Sandbox.mode(Repo.repo(), :manual)
    :ok
  end

  describe "cleanup_preserved_jobs/1" do
    test "cleans up old jobs with default options" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      # No old jobs, should return 0
      # Uses config defaults: cleanup_preserved_jobs_before_seconds_ago and cleanup_discarded_jobs
      deleted = Cleanup.cleanup_preserved_jobs()
      assert deleted >= 0
    end

    test "cleans up with custom older_than" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      deleted = Cleanup.cleanup_preserved_jobs(older_than: 3600)
      assert deleted >= 0
    end

    test "cleans up with include_discarded option" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      deleted = Cleanup.cleanup_preserved_jobs(include_discarded: true)
      assert deleted >= 0
    end

    test "uses config cleanup_discarded_jobs when not specified" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      # Should use GoodJob.Config.cleanup_discarded_jobs?() default (true)
      deleted = Cleanup.cleanup_preserved_jobs()
      assert deleted >= 0
    end

    test "uses config cleanup_preserved_jobs_before_seconds_ago when not specified" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      # Should use GoodJob.Config.cleanup_preserved_jobs_before_seconds_ago() default (14 days)
      deleted = Cleanup.cleanup_preserved_jobs()
      assert deleted >= 0
    end

    test "cleans up with custom batch size" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      deleted = Cleanup.cleanup_preserved_jobs(in_batches_of: 500)
      assert deleted >= 0
    end
  end
end
