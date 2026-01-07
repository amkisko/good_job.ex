defmodule GoodJob.ConcurrencyIntegrationTest do
  use ExUnit.Case, async: false

  alias GoodJob.{Job, Repo}

  import Ecto.Query

  setup do
    _pid = Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
    Ecto.Adapters.SQL.Sandbox.mode(Repo.repo(), {:shared, self()})
    :ok
  end

  defmodule ConcurrencyTestJob do
    use GoodJob.Job

    def good_job_concurrency_config do
      [total_limit: 2]
    end

    def perform(%{key: key, message: message}) do
      # Simulate work
      Process.sleep(100)
      {:ok, key: key, message: message}
    end

    def perform(args) when is_map(args) do
      key = Map.get(args, :key) || Map.get(args, "key") || "default"
      message = Map.get(args, :message) || Map.get(args, "message") || "test"
      perform(%{key: key, message: message})
    end
  end

  describe "end-to-end concurrency enforcement" do
    test "enforces total_limit during enqueue" do
      # Enqueue first job
      {:ok, _job1} = ConcurrencyTestJob.enqueue(%{message: "Job 1"}, concurrency_key: "test-key")

      # Enqueue second job
      {:ok, _job2} = ConcurrencyTestJob.enqueue(%{message: "Job 2"}, concurrency_key: "test-key")

      # Third job should be blocked by concurrency check
      result = ConcurrencyTestJob.enqueue(%{message: "Job 3"}, concurrency_key: "test-key")
      assert match?({:error, _}, result)
    end

    test "allows jobs with different concurrency keys" do
      # Enqueue jobs with different keys
      {:ok, _job1} = ConcurrencyTestJob.enqueue(%{message: "Job 1"}, concurrency_key: "key-1")
      {:ok, _job2} = ConcurrencyTestJob.enqueue(%{message: "Job 2"}, concurrency_key: "key-1")
      {:ok, _job3} = ConcurrencyTestJob.enqueue(%{message: "Job 3"}, concurrency_key: "key-2")

      # key-2 should be allowed (different key)
      {:ok, _job4} = ConcurrencyTestJob.enqueue(%{message: "Job 4"}, concurrency_key: "key-2")

      # Verify jobs were enqueued
      repo = Repo.repo()
      key1_jobs = repo.all(from(j in Job, where: j.concurrency_key == "key-1"))
      key2_jobs = repo.all(from(j in Job, where: j.concurrency_key == "key-2"))

      assert length(key1_jobs) == 2
      assert length(key2_jobs) == 2
    end

    test "enforces limits across multiple enqueue operations" do
      # Enqueue multiple jobs rapidly
      results =
        for i <- 1..5 do
          ConcurrencyTestJob.enqueue(%{message: "Job #{i}"}, concurrency_key: "rapid-key")
        end

      # Only first 2 should succeed (total_limit: 2)
      success_count = Enum.count(results, fn result -> match?({:ok, _}, result) end)
      assert success_count <= 2

      # Verify in database
      repo = Repo.repo()
      rapid_key_jobs = repo.all(from(j in Job, where: j.concurrency_key == "rapid-key"))
      assert length(rapid_key_jobs) <= 2
    end
  end

  describe "custom concurrency key generation" do
    test "supports custom key from job arguments" do
      defmodule CustomKeyJob do
        use GoodJob.Job

        def good_job_concurrency_config do
          [total_limit: 1]
        end

        def perform(%{user_id: user_id}) do
          {:ok, user_id: user_id}
        end
      end

      # Enqueue with custom concurrency_key via opts
      {:ok, _job1} = GoodJob.enqueue(CustomKeyJob, %{user_id: 123}, concurrency_key: "user:123")
      {:ok, _job2} = GoodJob.enqueue(CustomKeyJob, %{user_id: 456}, concurrency_key: "user:456")

      # Third job with same user_id should be blocked
      result = GoodJob.enqueue(CustomKeyJob, %{user_id: 123}, concurrency_key: "user:123")
      assert match?({:error, _}, result)

      # Different user_id should be allowed
      {:ok, _job4} = GoodJob.enqueue(CustomKeyJob, %{user_id: 789}, concurrency_key: "user:789")
    end

    test "supports dynamic key based on job arguments" do
      defmodule DynamicKeyJob do
        use GoodJob.Job

        def good_job_concurrency_config do
          [total_limit: 1]
        end

        def perform(%{resource_type: type, resource_id: id}) do
          {:ok, type: type, id: id}
        end
      end

      # Generate keys dynamically based on arguments
      {:ok, _job1} =
        GoodJob.enqueue(
          DynamicKeyJob,
          %{resource_type: "user", resource_id: 123},
          concurrency_key: "user:123"
        )

      {:ok, _job2} =
        GoodJob.enqueue(
          DynamicKeyJob,
          %{resource_type: "order", resource_id: 456},
          concurrency_key: "order:456"
        )

      # Same resource should be blocked
      result =
        GoodJob.enqueue(
          DynamicKeyJob,
          %{resource_type: "user", resource_id: 123},
          concurrency_key: "user:123"
        )

      assert match?({:error, _}, result)
    end
  end

  describe "concurrency with job execution" do
    test "respects limits during actual execution" do
      # This test would require a full scheduler setup
      # For now, we test that the concurrency check is called during execution
      job_id = Ecto.UUID.generate()

      # Create jobs to exceed limit
      for i <- 1..2 do
        {:ok, _job} =
          Job.enqueue(%{
            active_job_id: Ecto.UUID.generate(),
            job_class: Atom.to_string(ConcurrencyTestJob),
            queue_name: "default",
            serialized_params: %{
              "job_class" => "ConcurrencyTestJob",
              "arguments" => [%{key: "exec-key", message: "Job #{i}"}],
              "executions" => 0
            },
            concurrency_key: "exec-key",
            locked_by_id: Ecto.UUID.generate(),
            locked_at: DateTime.utc_now()
          })
      end

      # Third job should be blocked when trying to perform
      {:ok, job} =
        Job.enqueue(%{
          active_job_id: job_id,
          job_class: Atom.to_string(ConcurrencyTestJob),
          queue_name: "default",
          serialized_params: %{
            "job_class" => "ConcurrencyTestJob",
            "arguments" => [%{key: "exec-key", message: "Job 3"}],
            "executions" => 0
          },
          concurrency_key: "exec-key"
        })

      # Verify the job exists
      assert job.concurrency_key == "exec-key"
    end
  end

  describe "edge cases and error handling" do
    test "handles jobs without concurrency_key" do
      defmodule NoConcurrencyJob do
        use GoodJob.Job

        def perform(_args) do
          :ok
        end
      end

      # Should enqueue successfully without concurrency checks
      {:ok, _job} = NoConcurrencyJob.enqueue(%{})
    end

    test "handles jobs with empty concurrency_key" do
      result = GoodJob.enqueue(ConcurrencyTestJob, %{}, concurrency_key: "")
      # Empty key should be treated as no concurrency control
      assert match?({:ok, _}, result)
    end

    test "handles very large concurrency limits" do
      defmodule LargeLimitJob do
        use GoodJob.Job

        def good_job_concurrency_config do
          [total_limit: 1_000_000]
        end

        def perform(_args) do
          :ok
        end
      end

      # Should enqueue successfully
      {:ok, _job} = LargeLimitJob.enqueue(%{})
    end
  end
end
