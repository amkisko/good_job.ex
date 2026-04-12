defmodule GoodJob.JobTest do
  use ExUnit.Case, async: false
  use GoodJob.Testing.JobCase

  defmodule TestJob do
    use GoodJob.Job

    @impl GoodJob.Behaviour
    def perform(_args) do
      :ok
    end
  end

  defmodule CustomJob do
    use GoodJob.Job,
      queue: "custom",
      priority: 5,
      max_attempts: 10,
      timeout: 30_000,
      tags: ["important", "billing"]

    @impl GoodJob.Behaviour
    def perform(_args) do
      :ok
    end
  end

  defmodule JobWithCallbacks do
    use GoodJob.Job

    @impl GoodJob.Behaviour
    def perform(_args) do
      :ok
    end

    @impl true
    def backoff(attempt) do
      GoodJob.Backoff.linear(attempt, base: 10)
    end

    @impl true
    def max_attempts do
      15
    end

    def good_job_concurrency_config do
      [key: fn _args -> "test_key" end, limit: 3]
    end
  end

  describe "use GoodJob.Job" do
    test "defines default queue" do
      assert TestJob.__good_job_queue__() == "default"
    end

    test "defines default priority" do
      assert TestJob.__good_job_priority__() == 0
    end

    test "defines default max_attempts" do
      # Default is 5
      assert TestJob.__good_job_max_attempts__() == 5
    end

    test "defines default timeout" do
      assert TestJob.__good_job_timeout__() == :infinity
    end

    test "defines default tags" do
      assert TestJob.__good_job_tags__() == []
    end

    test "allows custom queue" do
      assert CustomJob.__good_job_queue__() == "custom"
    end

    test "allows custom priority" do
      assert CustomJob.__good_job_priority__() == 5
    end

    test "allows custom max_attempts" do
      assert CustomJob.__good_job_max_attempts__() == 10
    end

    test "allows custom timeout" do
      assert CustomJob.__good_job_timeout__() == 30_000
    end

    test "allows custom tags" do
      assert CustomJob.__good_job_tags__() == ["important", "billing"]
    end

    test "implements GoodJob.Behaviour" do
      assert function_exported?(TestJob, :perform, 1)
    end

    test "defines enqueue/2 function" do
      assert function_exported?(TestJob, :enqueue, 2)
    end

    test "defines backoff/1 function" do
      assert function_exported?(TestJob, :backoff, 1)
    end

    test "allows overriding backoff" do
      assert JobWithCallbacks.backoff(1) == 10
      assert JobWithCallbacks.backoff(2) == 20
    end

    test "allows overriding max_attempts" do
      assert JobWithCallbacks.max_attempts() == 15
    end

    test "allows overriding concurrency config" do
      config = JobWithCallbacks.good_job_concurrency_config()
      assert config[:key].(%{}) == "test_key"
      assert config[:limit] == 3
    end

    test "defines perform_now/1 function" do
      assert function_exported?(TestJob, :perform_now, 1)
    end

    test "defines perform_later/1 function" do
      assert function_exported?(TestJob, :perform_later, 1)
    end

    test "defines new/2 function" do
      assert function_exported?(TestJob, :new, 2)
    end

    test "defines set/1 function" do
      assert function_exported?(TestJob, :set, 1)
    end
  end

  describe "perform_now/1" do
    test "executes job immediately" do
      result = TestJob.perform_now(%{data: "test"})
      assert match?({:ok, _job}, result)
    end
  end

  describe "perform_later/1" do
    test "enqueues job for later execution" do
      result = TestJob.perform_later(%{data: "test"})
      assert match?({:ok, _job}, result)
    end
  end

  describe "new/2 and perform" do
    test "creates instance and executes directly" do
      job = TestJob.new(%{data: "test"})
      assert %GoodJob.Job.Instance{} = job
      assert job.job_module == TestJob
      assert job.args == %{data: "test"}

      # Execute the instance (Ruby-like: MyJob.new(args).perform)
      # In Elixir: Instance.perform(MyJob.new(args))
      result = GoodJob.Job.Instance.perform(job)
      assert result == :ok
    end
  end

  describe "set/1 and perform_later" do
    test "creates configured job and enqueues" do
      configured_job = TestJob.set(queue: "high_priority")
      assert %GoodJob.ConfiguredJob{} = configured_job

      # Ruby-like: MyJob.set(options).perform_later(args)
      # In Elixir: ConfiguredJob.perform_later(MyJob.set(options), args)
      result = GoodJob.ConfiguredJob.perform_later(configured_job, %{data: "test"})
      assert match?({:ok, _job}, result)
    end
  end

  describe "delete_many/1 and retry_many/1" do
    test "delete_many removes matching rows and returns count" do
      {:ok, j1} =
        Job.enqueue(%{
          active_job_id: Ecto.UUID.generate(),
          job_class: "T",
          queue_name: "default",
          serialized_params: %{"arguments" => []}
        })

      {:ok, j2} =
        Job.enqueue(%{
          active_job_id: Ecto.UUID.generate(),
          job_class: "T",
          queue_name: "default",
          serialized_params: %{"arguments" => []}
        })

      assert {:ok, 2} == Job.delete_many([j1.id, j2.id])
      assert is_nil(Job.find_by_id(j1.id))
      assert is_nil(Job.find_by_id(j2.id))
    end

    test "delete_many with no ids returns zero" do
      assert {:ok, 0} == Job.delete_many([])
    end

    test "retry_many clears finished state for multiple jobs" do
      repo = GoodJob.Repo.repo()
      now = DateTime.utc_now()

      {:ok, j1} =
        Job.enqueue(%{
          active_job_id: Ecto.UUID.generate(),
          job_class: "T",
          queue_name: "default",
          serialized_params: %{"arguments" => []}
        })

      {:ok, j2} =
        Job.enqueue(%{
          active_job_id: Ecto.UUID.generate(),
          job_class: "T",
          queue_name: "default",
          serialized_params: %{"arguments" => []}
        })

      _ = repo.update!(Job.changeset(j1, %{finished_at: now, error: "e1"}))
      _ = repo.update!(Job.changeset(j2, %{finished_at: now, error: "e2"}))

      assert {:ok, 2} == Job.retry_many([j1.id, j2.id])

      f1 = Job.find_by_id(j1.id)
      f2 = Job.find_by_id(j2.id)
      assert is_nil(f1.finished_at)
      assert is_nil(f1.error)
      assert is_nil(f2.finished_at)
      assert is_nil(f2.error)
    end
  end
end
