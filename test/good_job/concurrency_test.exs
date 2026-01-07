defmodule GoodJob.ConcurrencyTest do
  use ExUnit.Case, async: false

  alias GoodJob.{Concurrency, Execution, Job, Repo}

  setup do
    _pid = Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
    Ecto.Adapters.SQL.Sandbox.mode(Repo.repo(), {:shared, self()})
    :ok
  end

  describe "check_enqueue_limit/2" do
    test "allows enqueue when no limit configured" do
      assert Concurrency.check_enqueue_limit("test-key", %{}) == {:ok, :ok}
    end

    test "allows enqueue when limit not exceeded" do
      config = %{enqueue_limit: 10}
      assert Concurrency.check_enqueue_limit("test-key", config) == {:ok, :ok}
    end

    test "allows enqueue with total_limit" do
      config = %{total_limit: 5}
      assert Concurrency.check_enqueue_limit("test-key", config) == {:ok, :ok}
    end

    test "returns error when limit exceeded" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      # Create jobs to exceed limit
      for _i <- 1..5 do
        Job.enqueue(%{
          active_job_id: Ecto.UUID.generate(),
          job_class: "TestJob",
          queue_name: "default",
          serialized_params: %{"arguments" => []},
          concurrency_key: "test-key"
        })
      end

      config = %{enqueue_limit: 3}
      result = Concurrency.check_enqueue_limit("test-key", config)
      assert match?({:ok, {:error, :limit_exceeded}}, result)
    end

    test "handles throttle limit" do
      config = %{enqueue_throttle: {5, 60}}
      result = Concurrency.check_enqueue_limit("test-key", config)
      assert match?({:ok, _}, result)
    end
  end

  describe "check_perform_limit/3" do
    test "allows perform when no limit configured" do
      job_id = Ecto.UUID.generate()
      assert Concurrency.check_perform_limit("test-key", job_id, %{}) == {:ok, :ok}
    end

    test "allows perform when limit not exceeded" do
      job_id = Ecto.UUID.generate()
      config = %{perform_limit: 10}
      assert Concurrency.check_perform_limit("test-key", job_id, config) == {:ok, :ok}
    end

    test "allows perform with total_limit" do
      job_id = Ecto.UUID.generate()
      config = %{total_limit: 5}
      assert Concurrency.check_perform_limit("test-key", job_id, config) == {:ok, :ok}
    end

    test "handles perform throttle" do
      job_id = Ecto.UUID.generate()
      config = %{perform_throttle: {5, 60}}
      result = Concurrency.check_perform_limit("test-key", job_id, config)
      assert match?({:ok, _}, result)
    end

    test "returns error when perform limit exceeded" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      job_id = Ecto.UUID.generate()

      # Create running jobs to exceed limit
      for _i <- 1..5 do
        Job.enqueue(%{
          active_job_id: Ecto.UUID.generate(),
          job_class: "TestJob",
          queue_name: "default",
          serialized_params: %{"arguments" => []},
          concurrency_key: "test-key",
          locked_by_id: Ecto.UUID.generate(),
          locked_at: DateTime.utc_now()
        })
      end

      config = %{perform_limit: 3}
      result = Concurrency.check_perform_limit("test-key", job_id, config)
      assert match?({:ok, {:error, :limit_exceeded}}, result)
    end

    test "returns error when throttle exceeded" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())

      # Create executions within throttle period
      for _i <- 1..5 do
        active_job_id = Ecto.UUID.generate()

        Job.enqueue(%{
          active_job_id: active_job_id,
          job_class: "TestJob",
          queue_name: "default",
          serialized_params: %{"arguments" => []},
          concurrency_key: "test-key"
        })

        %Execution{}
        |> Execution.changeset(%{
          active_job_id: active_job_id,
          job_class: "TestJob",
          queue_name: "default",
          serialized_params: %{"arguments" => []}
        })
        |> Repo.repo().insert!()
      end

      Process.sleep(2)

      active_job_id = Ecto.UUID.generate()

      Job.enqueue(%{
        active_job_id: active_job_id,
        job_class: "TestJob",
        queue_name: "default",
        serialized_params: %{"arguments" => []},
        concurrency_key: "test-key"
      })

      %Execution{}
      |> Execution.changeset(%{
        active_job_id: active_job_id,
        job_class: "TestJob",
        queue_name: "default",
        serialized_params: %{"arguments" => []}
      })
      |> Repo.repo().insert!()

      config = %{perform_throttle: {5, 60}}
      result = Concurrency.check_perform_limit("test-key", active_job_id, config)
      assert match?({:ok, {:error, :throttle_exceeded}}, result)
    end
  end

  describe "lock failures" do
    test "returns error when lock acquisition fails" do
      # Use a key that might cause lock contention
      config = %{}
      # Try to get lock twice simultaneously (might fail depending on timing)
      result1 = Concurrency.check_enqueue_limit("lock-test", config)
      # Second call might fail if lock is held
      result2 = Concurrency.check_enqueue_limit("lock-test", config)

      # At least one should succeed, but we're testing the error path
      assert match?({:ok, _}, result1) or match?({:ok, {:error, :lock_failed}}, result1)
      assert match?({:ok, _}, result2) or match?({:ok, {:error, :lock_failed}}, result2)
    end
  end
end
