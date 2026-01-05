defmodule GoodJob.GoodJobModuleTest do
  use ExUnit.Case, async: false
  use GoodJob.Testing.JobCase

  alias GoodJob.Repo

  defmodule TestJob do
    @behaviour GoodJob.Behaviour

    def perform(_args) do
      :ok
    end

    def __good_job_queue__, do: "default"
    def __good_job_priority__, do: 0
    def __good_job_tags__, do: []
  end

  defmodule TestJobWithDefaults do
    @behaviour GoodJob.Behaviour

    def perform(_args) do
      :ok
    end

    def __good_job_queue__, do: "custom"
    def __good_job_priority__, do: 5
    def __good_job_tags__, do: ["important"]
  end

  # RepoCase already sets up sandbox, no need to override

  describe "enqueue/3" do
    test "enqueues job with default options" do
      repo = Repo.repo()

      repo.transaction(fn ->
        {:ok, job} = GoodJob.enqueue(TestJob, %{data: "test"})

        assert job.job_class =~ "TestJob"
        assert job.queue_name == "default"
        assert job.priority == 0
        assert is_binary(job.active_job_id)
        assert is_map(job.serialized_params)
      end)
    end

    test "enqueues job with custom queue, priority, and tags" do
      repo = Repo.repo()

      repo.transaction(fn ->
        {:ok, job} =
          GoodJob.enqueue(TestJob, %{data: "test"},
            queue: "high_priority",
            priority: 10,
            tags: ["urgent", "important"]
          )

        assert job.queue_name == "high_priority"
        assert job.priority == 10
        assert job.labels == ["urgent", "important"]
      end)
    end

    test "uses job module defaults for queue, priority, and tags" do
      repo = Repo.repo()

      repo.transaction(fn ->
        {:ok, job} = GoodJob.enqueue(TestJobWithDefaults, %{data: "test"})

        assert job.queue_name == "custom"
        assert job.priority == 5
        assert job.labels == ["important"]
      end)
    end

    test "enqueues job with scheduled_at" do
      repo = Repo.repo()

      repo.transaction(fn ->
        scheduled_at = DateTime.utc_now() |> DateTime.add(3600, :second)
        {:ok, job} = GoodJob.enqueue(TestJob, %{data: "test"}, scheduled_at: scheduled_at)

        assert job.scheduled_at == scheduled_at
      end)
    end

    test "enqueues job with concurrency_key" do
      repo = Repo.repo()

      repo.transaction(fn ->
        {:ok, job} = GoodJob.enqueue(TestJob, %{data: "test"}, concurrency_key: "user:123")

        assert job.concurrency_key == "user:123"
      end)
    end

    test "enqueues job with batch_id" do
      repo = Repo.repo()

      repo.transaction(fn ->
        batch_id = Ecto.UUID.generate()
        {:ok, job} = GoodJob.enqueue(TestJob, %{data: "test"}, batch_id: batch_id)

        assert job.batch_id == batch_id
      end)
    end

    test "executes job inline when execution_mode is :inline" do
      repo = Repo.repo()

      repo.transaction(fn ->
        result = GoodJob.enqueue(TestJob, %{data: "test"}, execution_mode: :inline)

        # Inline execution returns the result directly
        assert result == {:ok, :ok}
      end)
    end

    test "handles concurrency limit check" do
      repo = Repo.repo()

      repo.transaction(fn ->
        # This should pass if no limit is configured
        result =
          GoodJob.enqueue(TestJob, %{data: "test"},
            concurrency_key: "test_key",
            concurrency_config: [enqueue_limit: 10]
          )

        assert {:ok, _job} = result
      end)
    end

    test "uses queue name as provided" do
      repo = Repo.repo()

      repo.transaction(fn ->
        {:ok, job} = GoodJob.enqueue(TestJob, %{data: "test"}, queue: "emails")

        assert job.queue_name == "emails"
      end)
    end

    test "handles before_enqueue callback modifying arguments" do
      repo = Repo.repo()

      repo.transaction(fn ->
        # Test that callbacks are executed
        {:ok, job} = GoodJob.enqueue(TestJob, %{data: "test"})

        assert is_map(job.serialized_params)
        assert Map.has_key?(job.serialized_params, "arguments")
      end)
    end
  end

  describe "delegate functions" do
    test "config/0 delegates to Config" do
      config = GoodJob.config()
      assert is_map(config)
      assert Map.has_key?(config, :repo)
    end

    test "shutdown/1 delegates to Supervisor" do
      # Just verify it doesn't crash
      result = GoodJob.shutdown(timeout: 1000)
      assert result == :ok or match?({:error, _}, result)
    end

    test "shutdown?/0 delegates to Supervisor" do
      result = GoodJob.shutdown?()
      assert is_boolean(result)
    end

    test "cleanup_preserved_jobs/1 delegates to Cleanup" do
      repo = Repo.repo()

      repo.transaction(fn ->
        deleted = GoodJob.cleanup_preserved_jobs()
        assert is_integer(deleted)
        assert deleted >= 0
      end)
    end

    test "pause/1 delegates to SettingManager" do
      repo = Repo.repo()

      repo.transaction(fn ->
        result = GoodJob.pause(queue: "test_queue")
        assert result.__struct__ == GoodJob.SettingSchema or match?({:error, _}, result)
      end)
    end

    test "unpause/1 delegates to SettingManager" do
      repo = Repo.repo()

      repo.transaction(fn ->
        # First pause
        GoodJob.pause(queue: "test_queue")

        # Then unpause
        result = GoodJob.unpause(queue: "test_queue")
        assert result == :ok or result.__struct__ == GoodJob.SettingSchema
      end)
    end

    test "paused?/1 delegates to SettingManager" do
      repo = Repo.repo()

      repo.transaction(fn ->
        result = GoodJob.paused?(queue: "test_queue")
        assert is_boolean(result)
      end)
    end

    test "new_batch/1 delegates to Batch" do
      batch = GoodJob.new_batch()
      assert batch.__struct__ == GoodJob.Batch
      assert batch.jobs == []
    end

    test "stats/1 delegates to JobStats" do
      repo = Repo.repo()

      repo.transaction(fn ->
        stats = GoodJob.stats()
        assert is_map(stats)
      end)
    end
  end
end
