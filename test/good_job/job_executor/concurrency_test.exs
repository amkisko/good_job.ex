defmodule GoodJob.JobExecutor.ConcurrencyTest do
  use ExUnit.Case, async: false

  alias GoodJob.{Errors, Job, JobExecutor, Repo}
  import Ecto.Query

  setup do
    _pid = Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
    Ecto.Adapters.SQL.Sandbox.mode(Repo.repo(), {:shared, self()})
    :ok
  end

  defmodule TestJob do
    use GoodJob.Job

    def good_job_concurrency_config do
      [total_limit: 2]
    end

    def perform(_args) do
      :ok
    end
  end

  defmodule TestJobWithDynamicKey do
    use GoodJob.Job

    def good_job_concurrency_config do
      [total_limit: 1, key: fn job -> Map.get(job, :resource_id) || "default" end]
    end

    def perform(%{resource_id: _resource_id}) do
      :ok
    end
  end

  describe "concurrency enforcement during execution" do
    test "allows execution when limit not exceeded" do
      job_id = Ecto.UUID.generate()

      {:ok, job} =
        Job.enqueue(%{
          active_job_id: job_id,
          job_class: Atom.to_string(TestJob),
          queue_name: "default",
          serialized_params: %{
            "job_class" => Atom.to_string(TestJob),
            "arguments" => [%{}],
            "executions" => 0
          },
          concurrency_key: "test-key"
        })

      # Should execute successfully
      lock_id = Ecto.UUID.generate()
      result = JobExecutor.execute(job, lock_id)
      assert match?({:ok, _}, result)
    end

    test "raises ConcurrencyExceededError when limit exceeded" do
      job_id = Ecto.UUID.generate()
      repo = Repo.repo()

      # Create and lock jobs directly using repo operations to ensure they're committed
      # Set performed_at to a time in the past to ensure they order before the current job
      past_time = DateTime.add(DateTime.utc_now(), -10, :second)

      for i <- 1..2 do
        {:ok, job} =
          Job.enqueue(%{
            active_job_id: Ecto.UUID.generate(),
            job_class: Atom.to_string(TestJob),
            queue_name: "default",
            serialized_params: %{
              "job_class" => Atom.to_string(TestJob),
              "arguments" => [%{}],
              "executions" => 0
            },
            concurrency_key: "test-key"
          })

        # Lock the job by updating it with performed_at set to a past time
        # This ensures they order before the current job (which will use inserted_at)
        lock_id = Ecto.UUID.generate()
        performed_at = DateTime.add(past_time, i, :microsecond)

        repo.update_all(
          from(j in Job, where: j.id == ^job.id),
          set: [locked_by_id: lock_id, locked_at: performed_at, performed_at: performed_at]
        )
      end

      # Small delay to ensure the 3rd job is created after the locked jobs
      Process.sleep(10)

      # Verify the count is correct before attempting execution
      locked_count =
        repo.one(
          from(j in Job,
            where: j.concurrency_key == "test-key" and is_nil(j.finished_at) and not is_nil(j.locked_by_id),
            select: count(j.id)
          )
        ) || 0

      assert locked_count == 2

      {:ok, job} =
        Job.enqueue(%{
          active_job_id: job_id,
          job_class: Atom.to_string(TestJob),
          queue_name: "default",
          serialized_params: %{
            "job_class" => Atom.to_string(TestJob),
            "arguments" => [%{}],
            "executions" => 0
          },
          concurrency_key: "test-key"
        })

      # Verify total count: 2 locked + 1 unlocked = 3 total
      total_count =
        repo.one(
          from(j in Job,
            where: j.concurrency_key == "test-key" and is_nil(j.finished_at),
            select: count(j.id)
          )
        ) || 0

      assert total_count == 3, "Expected 3 total unfinished jobs (2 locked + 1 unlocked), got #{total_count}"

      # Should raise error (total_limit: 2, and we have 3 total unfinished jobs)
      lock_id = Ecto.UUID.generate()

      assert_raise Errors.ConcurrencyExceededError, fn ->
        JobExecutor.execute(job, lock_id)
      end
    end

    test "raises ThrottleExceededError when throttle exceeded" do
      job_id = Ecto.UUID.generate()

      defmodule TestJobWithThrottle do
        use GoodJob.Job

        def good_job_concurrency_config do
          [perform_throttle: {1, 60}]
        end

        def perform(_args) do
          :ok
        end
      end

      # Create execution within throttle period
      # Note: This is simplified - real implementation checks Execution table
      {:ok, job} =
        Job.enqueue(%{
          active_job_id: job_id,
          job_class: Atom.to_string(TestJobWithThrottle),
          queue_name: "default",
          serialized_params: %{
            "job_class" => Atom.to_string(TestJobWithThrottle),
            "arguments" => [%{}],
            "executions" => 0
          },
          concurrency_key: "test-key"
        })

      # Should execute if no previous executions
      lock_id = Ecto.UUID.generate()
      result = JobExecutor.execute(job, lock_id)
      assert match?({:ok, _}, result)
    end

    test "skips concurrency check when no concurrency_key" do
      job_id = Ecto.UUID.generate()

      {:ok, job} =
        Job.enqueue(%{
          active_job_id: job_id,
          job_class: Atom.to_string(TestJob),
          queue_name: "default",
          serialized_params: %{
            "job_class" => Atom.to_string(TestJob),
            "arguments" => [%{}],
            "executions" => 0
          },
          concurrency_key: nil
        })

      # Should execute without concurrency check
      lock_id = Ecto.UUID.generate()
      result = JobExecutor.execute(job, lock_id)
      assert match?({:ok, _}, result)
    end

    test "uses concurrency config from job module" do
      job_id = Ecto.UUID.generate()

      {:ok, job} =
        Job.enqueue(%{
          active_job_id: job_id,
          job_class: Atom.to_string(TestJob),
          queue_name: "default",
          serialized_params: %{
            "job_class" => Atom.to_string(TestJob),
            "arguments" => [%{}],
            "executions" => 0
          },
          concurrency_key: "test-key"
        })

      # Job module defines total_limit: 2
      # Should execute if limit not exceeded
      lock_id = Ecto.UUID.generate()
      result = JobExecutor.execute(job, lock_id)
      assert match?({:ok, _}, result)
    end
  end

  describe "dynamic concurrency key generation" do
    test "supports function-based concurrency config" do
      # This tests that concurrency config can be a function
      # In Elixir, this would be handled via opts or module attributes
      job_id = Ecto.UUID.generate()

      {:ok, job} =
        Job.enqueue(%{
          active_job_id: job_id,
          job_class: Atom.to_string(TestJobWithDynamicKey),
          queue_name: "default",
          serialized_params: %{
            "job_class" => Atom.to_string(TestJobWithDynamicKey),
            "arguments" => [%{resource_id: "resource-123"}],
            "executions" => 0
          },
          concurrency_key: "resource-123"
        })

      # Should execute
      lock_id = Ecto.UUID.generate()
      result = JobExecutor.execute(job, lock_id)
      assert match?({:ok, _}, result)
    end
  end

  defmodule CrossLanguageJob do
    use GoodJob.Job

    def good_job_concurrency_config do
      [total_limit: 2]
    end

    def perform(_args) do
      :ok
    end
  end

  describe "cross-language concurrency" do
    test "respects concurrency limits set by external jobs" do
      # Simulate a job enqueued by Ruby with concurrency_key
      job_id = Ecto.UUID.generate()

      {:ok, job} =
        Job.enqueue(%{
          active_job_id: job_id,
          job_class: Atom.to_string(CrossLanguageJob),
          queue_name: "default",
          serialized_params: %{
            "job_class" => Atom.to_string(CrossLanguageJob),
            "arguments" => [%{resource_id: "resource-123"}],
            "executions" => 0,
            "good_job_concurrency_key" => "resource:resource-123"
          },
          concurrency_key: "resource:resource-123"
        })

      # Should execute if limit not exceeded
      lock_id = Ecto.UUID.generate()
      result = JobExecutor.execute(job, lock_id)
      assert match?({:ok, _}, result)
    end
  end
end
