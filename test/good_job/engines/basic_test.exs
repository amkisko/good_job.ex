defmodule GoodJob.Engines.BasicTest do
  use ExUnit.Case, async: false
  use GoodJob.Testing.JobCase

  alias GoodJob.{Config, Engines.Basic, Job, Repo}

  describe "insert_job/3" do
    test "inserts a job successfully" do
      repo = Repo.repo()

      repo.transaction(fn ->
        config = Config.config()

        changeset =
          Job.changeset(%Job{}, %{
            active_job_id: Ecto.UUID.generate(),
            job_class: "TestJob",
            queue_name: "default",
            serialized_params: %{"arguments" => %{}}
          })

        {:ok, job} = Basic.insert_job(config, changeset, [])
        assert %Job{} = job
        assert job.id != nil
      end)
    end

    test "returns error for invalid changeset" do
      repo = Repo.repo()

      repo.transaction(fn ->
        config = Config.config()
        changeset = Job.changeset(%Job{}, %{})

        {:error, changeset} = Basic.insert_job(config, changeset, [])
        assert %Ecto.Changeset{} = changeset
      end)
    end
  end

  describe "fetch_jobs/2" do
    test "fetches available jobs" do
      repo = Repo.repo()

      repo.transaction(fn ->
        config = Config.config()
        GoodJob.enqueue(TestJob, %{data: "test"})

        {:ok, jobs} = Basic.fetch_jobs(config, [])
        assert is_list(jobs)
      end)
    end

    test "fetches jobs for specific queue" do
      repo = Repo.repo()

      repo.transaction(fn ->
        config = Config.config()
        GoodJob.enqueue(TestJob, %{data: "test"}, queue: "queue1")

        {:ok, jobs} = Basic.fetch_jobs(config, queue: "queue1")
        assert is_list(jobs)
      end)
    end

    test "respects limit option" do
      repo = Repo.repo()

      repo.transaction(fn ->
        config = Config.config()
        GoodJob.enqueue(TestJob, %{data: "test1"})
        GoodJob.enqueue(TestJob, %{data: "test2"})

        {:ok, jobs} = Basic.fetch_jobs(config, limit: 1)
        assert length(jobs) <= 1
      end)
    end
  end

  describe "complete_job/2" do
    test "marks job as completed" do
      repo = Repo.repo()

      repo.transaction(fn ->
        config = Config.config()
        {:ok, job} = GoodJob.enqueue(TestJob, %{data: "test"})

        :ok = Basic.complete_job(config, job)

        updated_job = repo.get!(Job, job.id)
        assert updated_job.performed_at != nil
        assert updated_job.finished_at != nil
        assert updated_job.error == nil
      end)
    end
  end

  describe "discard_job/2" do
    test "marks job as discarded" do
      repo = Repo.repo()

      repo.transaction(fn ->
        config = Config.config()
        {:ok, job} = GoodJob.enqueue(TestJob, %{data: "test"})

        :ok = Basic.discard_job(config, job)

        updated_job = repo.get!(Job, job.id)
        assert updated_job.performed_at != nil
        assert updated_job.finished_at != nil
        assert updated_job.error == "Job discarded"
      end)
    end
  end

  describe "error_job/3" do
    test "marks job for retry with scheduled_at" do
      repo = Repo.repo()

      repo.transaction(fn ->
        config = Config.config()
        {:ok, job} = GoodJob.enqueue(TestJob, %{data: "test"})
        initial_count = job.executions_count || 0

        :ok = Basic.error_job(config, job, 60)

        updated_job = repo.get!(Job, job.id)
        assert updated_job.finished_at == nil
        assert updated_job.scheduled_at != nil
        assert updated_job.executions_count == initial_count + 1
      end)
    end
  end
end
