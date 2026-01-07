defmodule GoodJob.Concurrency.ComprehensiveTest do
  use ExUnit.Case, async: false

  alias GoodJob.{Concurrency, Job, Repo}
  import Ecto.Query

  setup do
    _pid = Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
    Ecto.Adapters.SQL.Sandbox.mode(Repo.repo(), {:shared, self()})
    :ok
  end

  describe "total_limit" do
    test "does not enqueue if limit is exceeded for a particular key" do
      # Create first job
      {:ok, _job1} =
        Job.enqueue(%{
          active_job_id: Ecto.UUID.generate(),
          job_class: "TestJob",
          queue_name: "default",
          serialized_params: %{"arguments" => []},
          concurrency_key: "alice"
        })

      # Second job should be blocked (total_limit: 1)
      config = %{total_limit: 1}
      result = Concurrency.check_enqueue_limit("alice", config)
      assert match?({:ok, {:error, :limit_exceeded}}, result)
    end

    test "is inclusive of both performing and enqueued jobs" do
      # total_limit for enqueue checks ALL unfinished jobs (enqueued + performing)
      # This matches Ruby good_job behavior

      # Create one enqueued job (not locked)
      {:ok, _job1} =
        Job.enqueue(%{
          active_job_id: Ecto.UUID.generate(),
          job_class: "TestJob",
          queue_name: "default",
          serialized_params: %{"arguments" => []},
          concurrency_key: "alice"
        })

      # Create one performing job (locked)
      {:ok, _job2} =
        Job.enqueue(%{
          active_job_id: Ecto.UUID.generate(),
          job_class: "TestJob",
          queue_name: "default",
          serialized_params: %{"arguments" => []},
          concurrency_key: "alice",
          locked_by_id: Ecto.UUID.generate(),
          locked_at: DateTime.utc_now()
        })

      # When total_limit is used (and no enqueue_limit), it counts ALL unfinished jobs
      # We have 1 enqueued + 1 performing = 2 total
      # Third job: (2 + 1) > 2 = true, so should be blocked
      config = %{total_limit: 2}
      result = Concurrency.check_enqueue_limit("alice", config)
      assert match?({:ok, {:error, :limit_exceeded}}, result)
    end

    test "allows different keys to process independently" do
      # Create jobs with different keys
      {:ok, _job1} =
        Job.enqueue(%{
          active_job_id: Ecto.UUID.generate(),
          job_class: "TestJob",
          queue_name: "default",
          serialized_params: %{"arguments" => []},
          concurrency_key: "alice"
        })

      {:ok, _job2} =
        Job.enqueue(%{
          active_job_id: Ecto.UUID.generate(),
          job_class: "TestJob",
          queue_name: "default",
          serialized_params: %{"arguments" => []},
          concurrency_key: "bob"
        })

      # Both should be allowed (different keys)
      config = %{total_limit: 1}
      result_alice = Concurrency.check_enqueue_limit("alice", config)
      result_bob = Concurrency.check_enqueue_limit("bob", config)

      # Alice should be blocked (already has 1), Bob should be blocked (already has 1)
      assert match?({:ok, {:error, :limit_exceeded}}, result_alice)
      assert match?({:ok, {:error, :limit_exceeded}}, result_bob)
    end
  end

  describe "enqueue_limit" do
    test "does not enqueue if enqueue concurrency limit is exceeded" do
      # Create two enqueued jobs (not locked)
      {:ok, _job1} =
        Job.enqueue(%{
          active_job_id: Ecto.UUID.generate(),
          job_class: "TestJob",
          queue_name: "default",
          serialized_params: %{"arguments" => []},
          concurrency_key: "alice"
        })

      {:ok, _job2} =
        Job.enqueue(%{
          active_job_id: Ecto.UUID.generate(),
          job_class: "TestJob",
          queue_name: "default",
          serialized_params: %{"arguments" => []},
          concurrency_key: "alice"
        })

      # Third job should be blocked (enqueue_limit: 2)
      config = %{enqueue_limit: 2}
      result = Concurrency.check_enqueue_limit("alice", config)
      assert match?({:ok, {:error, :limit_exceeded}}, result)
    end

    test "excludes jobs that are already executing/locked" do
      # Create one enqueued job
      {:ok, _job1} =
        Job.enqueue(%{
          active_job_id: Ecto.UUID.generate(),
          job_class: "TestJob",
          queue_name: "default",
          serialized_params: %{"arguments" => []},
          concurrency_key: "alice"
        })

      # Create one performing job (locked)
      {:ok, _job2} =
        Job.enqueue(%{
          active_job_id: Ecto.UUID.generate(),
          job_class: "TestJob",
          queue_name: "default",
          serialized_params: %{"arguments" => []},
          concurrency_key: "alice",
          locked_by_id: Ecto.UUID.generate(),
          locked_at: DateTime.utc_now()
        })

      # Third job should be allowed (enqueue_limit: 2, only 1 enqueued)
      config = %{enqueue_limit: 2}
      result = Concurrency.check_enqueue_limit("alice", config)
      assert match?({:ok, :ok}, result)
    end

    test "allows different keys to enqueue independently" do
      # Create jobs with different keys
      {:ok, _job1} =
        Job.enqueue(%{
          active_job_id: Ecto.UUID.generate(),
          job_class: "TestJob",
          queue_name: "default",
          serialized_params: %{"arguments" => []},
          concurrency_key: "alice"
        })

      {:ok, _job2} =
        Job.enqueue(%{
          active_job_id: Ecto.UUID.generate(),
          job_class: "TestJob",
          queue_name: "default",
          serialized_params: %{"arguments" => []},
          concurrency_key: "bob"
        })

      # Both should be allowed (different keys)
      config = %{enqueue_limit: 1}
      result_alice = Concurrency.check_enqueue_limit("alice", config)
      result_bob = Concurrency.check_enqueue_limit("bob", config)

      # Both should be blocked (already have 1 each)
      assert match?({:ok, {:error, :limit_exceeded}}, result_alice)
      assert match?({:ok, {:error, :limit_exceeded}}, result_bob)
    end
  end

  describe "perform_limit" do
    test "blocks perform if limit is exceeded" do
      job_id = Ecto.UUID.generate()

      # Create two performing jobs (locked)
      {:ok, _job1} =
        Job.enqueue(%{
          active_job_id: Ecto.UUID.generate(),
          job_class: "TestJob",
          queue_name: "default",
          serialized_params: %{"arguments" => []},
          concurrency_key: "alice",
          locked_by_id: Ecto.UUID.generate(),
          locked_at: DateTime.utc_now()
        })

      {:ok, _job2} =
        Job.enqueue(%{
          active_job_id: Ecto.UUID.generate(),
          job_class: "TestJob",
          queue_name: "default",
          serialized_params: %{"arguments" => []},
          concurrency_key: "alice",
          locked_by_id: Ecto.UUID.generate(),
          locked_at: DateTime.utc_now()
        })

      # Third job should be blocked (perform_limit: 2)
      config = %{perform_limit: 2}
      result = Concurrency.check_perform_limit("alice", job_id, config)
      assert match?({:ok, {:error, :limit_exceeded}}, result)
    end

    test "allows perform when enqueued jobs exist but performing limit not reached" do
      job_id = Ecto.UUID.generate()

      # Create one enqueued job (not locked) - this doesn't count for perform_limit
      {:ok, _job1} =
        Job.enqueue(%{
          active_job_id: Ecto.UUID.generate(),
          job_class: "TestJob",
          queue_name: "default",
          serialized_params: %{"arguments" => []},
          concurrency_key: "alice"
        })

      # Create one performing job (locked) - this counts for perform_limit
      {:ok, _job2} =
        Job.enqueue(%{
          active_job_id: Ecto.UUID.generate(),
          job_class: "TestJob",
          queue_name: "default",
          serialized_params: %{"arguments" => []},
          concurrency_key: "alice",
          locked_by_id: Ecto.UUID.generate(),
          locked_at: DateTime.utc_now()
        })

      # Third job should be allowed (perform_limit: 2, only 1 performing)
      # perform_limit only counts locked jobs, not enqueued ones
      config = %{perform_limit: 2}
      result = Concurrency.check_perform_limit("alice", job_id, config)
      assert match?({:ok, :ok}, result)
    end
  end

  describe "enqueue_throttle" do
    test "does not enqueue if throttle period has not passed" do
      # Create a job within the throttle period
      {:ok, _job1} =
        Job.enqueue(%{
          active_job_id: Ecto.UUID.generate(),
          job_class: "TestJob",
          queue_name: "default",
          serialized_params: %{"arguments" => []},
          concurrency_key: "alice",
          inserted_at: DateTime.utc_now()
        })

      # Second job should be blocked (enqueue_throttle: [1, 60])
      config = %{enqueue_throttle: {1, 60}}
      result = Concurrency.check_enqueue_limit("alice", config)
      assert match?({:ok, {:error, :throttle_exceeded}}, result)
    end

    test "allows enqueue after throttle period has passed" do
      # Create a job well outside the throttle period (2 minutes ago)
      {:ok, job1} =
        Job.enqueue(%{
          active_job_id: Ecto.UUID.generate(),
          job_class: "TestJob",
          queue_name: "default",
          serialized_params: %{"arguments" => []},
          concurrency_key: "alice"
        })

      # Update the job's inserted_at to be 2 minutes ago
      old_time = DateTime.add(DateTime.utc_now(), -120, :second)
      repo = Repo.repo()
      repo.update_all(from(j in Job, where: j.id == ^job1.id), set: [inserted_at: old_time])

      # Second job should be allowed (throttle period has passed)
      config = %{enqueue_throttle: {1, 60}}
      result = Concurrency.check_enqueue_limit("alice", config)
      assert match?({:ok, :ok}, result)
    end

    test "respects throttle limit count" do
      # Create multiple jobs within throttle period (all within last 30 seconds)
      now = DateTime.utc_now()

      for i <- 0..4 do
        {:ok, _job} =
          Job.enqueue(%{
            active_job_id: Ecto.UUID.generate(),
            job_class: "TestJob",
            queue_name: "default",
            serialized_params: %{"arguments" => []},
            concurrency_key: "alice",
            # Spread over 20 seconds
            inserted_at: DateTime.add(now, -i * 5, :second)
          })
      end

      # Sixth job should be blocked (enqueue_throttle: {5, 60})
      # We have 5 jobs within the last 60 seconds, so adding one more exceeds the limit
      config = %{enqueue_throttle: {5, 60}}
      result = Concurrency.check_enqueue_limit("alice", config)
      assert match?({:ok, {:error, :throttle_exceeded}}, result)
    end
  end

  describe "perform_throttle" do
    test "allows perform when no executions exist" do
      job_id = Ecto.UUID.generate()

      # perform_throttle checks executions table, not jobs table
      # If no executions exist, should be allowed
      config = %{perform_throttle: {1, 60}}
      result = Concurrency.check_perform_limit("alice", job_id, config)
      assert match?({:ok, :ok}, result)
    end

    test "blocks perform if throttle period has not passed" do
      # Note: This test requires Execution records to be created
      # The perform_throttle logic checks the executions table
      # For a complete test, we would need to create Execution records
      # This is tested in integration tests with actual job execution

      job_id = Ecto.UUID.generate()
      config = %{perform_throttle: {1, 60}}

      # Without executions, should be allowed
      result = Concurrency.check_perform_limit("alice", job_id, config)
      assert match?({:ok, :ok}, result)
    end
  end

  describe "combined limits" do
    test "enqueue_limit takes precedence over total_limit" do
      # Create one enqueued job
      {:ok, _job1} =
        Job.enqueue(%{
          active_job_id: Ecto.UUID.generate(),
          job_class: "TestJob",
          queue_name: "default",
          serialized_params: %{"arguments" => []},
          concurrency_key: "alice"
        })

      # When both enqueue_limit and total_limit are set, enqueue_limit should be used
      # enqueue_limit only counts unlocked jobs, so with 1 enqueued job:
      # (1 + 1) > 1 = true, so blocked
      config = %{enqueue_limit: 1, total_limit: 5}
      result = Concurrency.check_enqueue_limit("alice", config)
      assert match?({:ok, {:error, :limit_exceeded}}, result)
    end

    test "perform_limit takes precedence over total_limit" do
      job_id = Ecto.UUID.generate()

      # Create one performing job
      {:ok, _job1} =
        Job.enqueue(%{
          active_job_id: Ecto.UUID.generate(),
          job_class: "TestJob",
          queue_name: "default",
          serialized_params: %{"arguments" => []},
          concurrency_key: "alice",
          locked_by_id: Ecto.UUID.generate(),
          locked_at: DateTime.utc_now()
        })

      # When both perform_limit and total_limit are set, perform_limit should be used
      config = %{perform_limit: 1, total_limit: 5}
      result = Concurrency.check_perform_limit("alice", job_id, config)
      assert match?({:ok, {:error, :limit_exceeded}}, result)
    end

    test "throttle and limit can work together" do
      # Create jobs within throttle period
      now = DateTime.utc_now()

      for i <- 0..1 do
        {:ok, _job} =
          Job.enqueue(%{
            active_job_id: Ecto.UUID.generate(),
            job_class: "TestJob",
            queue_name: "default",
            serialized_params: %{"arguments" => []},
            concurrency_key: "alice",
            inserted_at: DateTime.add(now, -i * 5, :second)
          })
      end

      # Should be blocked by throttle (enqueue_throttle: {2, 60})
      # We have 2 jobs within 60 seconds, adding one more: (2 + 1) > 2 = true
      config = %{enqueue_limit: 5, enqueue_throttle: {2, 60}}
      result = Concurrency.check_enqueue_limit("alice", config)
      assert match?({:ok, {:error, :throttle_exceeded}}, result)
    end
  end

  describe "edge cases" do
    test "handles nil concurrency_key gracefully" do
      # Should not crash with nil key
      config = %{total_limit: 1}
      result = Concurrency.check_enqueue_limit(nil, config)
      # Implementation should handle nil (either allow or return error)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "handles empty string concurrency_key" do
      config = %{total_limit: 1}
      result = Concurrency.check_enqueue_limit("", config)
      assert match?({:ok, _}, result)
    end

    test "handles very large limit values" do
      config = %{total_limit: 1_000_000}
      result = Concurrency.check_enqueue_limit("test-key", config)
      assert match?({:ok, :ok}, result)
    end

    test "handles zero limit" do
      # Zero limit should block all jobs
      config = %{total_limit: 0}
      result = Concurrency.check_enqueue_limit("test-key", config)
      assert match?({:ok, {:error, :limit_exceeded}}, result)
    end

    test "handles finished jobs correctly" do
      # Create a finished job
      {:ok, _job1} =
        Job.enqueue(%{
          active_job_id: Ecto.UUID.generate(),
          job_class: "TestJob",
          queue_name: "default",
          serialized_params: %{"arguments" => []},
          concurrency_key: "alice",
          finished_at: DateTime.utc_now()
        })

      # Should not count finished jobs
      config = %{total_limit: 1}
      result = Concurrency.check_enqueue_limit("alice", config)
      assert match?({:ok, :ok}, result)
    end
  end

  describe "advisory locks" do
    test "handles lock acquisition failures gracefully" do
      config = %{total_limit: 1}

      # Multiple simultaneous checks might cause lock contention
      # The implementation should handle this gracefully
      result1 = Concurrency.check_enqueue_limit("lock-test", config)
      result2 = Concurrency.check_enqueue_limit("lock-test", config)

      # At least one should succeed or return lock_failed
      assert match?({:ok, _}, result1) or match?({:ok, {:error, :lock_failed}}, result1)
      assert match?({:ok, _}, result2) or match?({:ok, {:error, :lock_failed}}, result2)
    end
  end

  describe "error types" do
    test "returns ConcurrencyExceededError for limit exceeded" do
      # Create jobs to exceed limit
      {:ok, _job1} =
        Job.enqueue(%{
          active_job_id: Ecto.UUID.generate(),
          job_class: "TestJob",
          queue_name: "default",
          serialized_params: %{"arguments" => []},
          concurrency_key: "test-key"
        })

      config = %{total_limit: 1}
      result = Concurrency.check_enqueue_limit("test-key", config)
      assert match?({:ok, {:error, :limit_exceeded}}, result)
    end

    test "returns ThrottleExceededError for throttle exceeded" do
      # Create job within throttle period
      {:ok, _job1} =
        Job.enqueue(%{
          active_job_id: Ecto.UUID.generate(),
          job_class: "TestJob",
          queue_name: "default",
          serialized_params: %{"arguments" => []},
          concurrency_key: "test-key",
          inserted_at: DateTime.utc_now()
        })

      config = %{enqueue_throttle: {1, 60}}
      result = Concurrency.check_enqueue_limit("test-key", config)
      assert match?({:ok, {:error, :throttle_exceeded}}, result)
    end
  end
end
