defmodule GoodJob.Scheduler.SupervisorTest do
  use ExUnit.Case, async: false

  alias GoodJob.Scheduler.Supervisor

  describe "start_link/1" do
    test "starts supervisor with queue configuration" do
      opts = [
        queue_string: "ex.test",
        max_processes: 3
      ]

      {:ok, pid} = Supervisor.start_link(opts)
      assert Process.alive?(pid)

      # Verify supervisor is running
      assert Process.alive?(pid)

      # Clean up
      GenServer.stop(pid, :normal)
    end

    test "starts supervisor with multiple queues" do
      queues = ["ex.queue1", "ex.queue2"]

      for queue <- queues do
        opts = [queue_string: queue, max_processes: 2]
        {:ok, pid} = Supervisor.start_link(opts)
        assert Process.alive?(pid)
        GenServer.stop(pid, :normal)
      end
    end
  end

  describe "queue concurrency parsing" do
    setup do
      # Save original config
      original_queues = Application.get_env(:good_job, :config, %{})[:queues]
      original_max_processes = Application.get_env(:good_job, :config, %{})[:max_processes]

      on_exit(fn ->
        # Restore original config
        config = Application.get_env(:good_job, :config, %{})
        config = Map.put(config, :queues, original_queues)
        config = Map.put(config, :max_processes, original_max_processes)
        Application.put_env(:good_job, :config, config)
      end)

      :ok
    end

    test "parses queue with concurrency (comma-separated legacy format)" do
      # Test legacy format: "queue1:5,queue2:10"
      Application.put_env(:good_job, :config, %{
        repo: GoodJob.TestRepo,
        queues: "ex.queue1:5,ex.queue2:10",
        max_processes: 3
      })

      {:ok, pid} = Supervisor.start_link([])
      assert Process.alive?(pid)

      # Verify children were created (should have 2 schedulers)
      children = :supervisor.which_children(pid)
      assert length(children) == 2

      GenServer.stop(pid, :normal)
    end

    test "parses semicolon-separated pools with concurrency" do
      # Test Ruby GoodJob format: "queue1:2;queue2:1;*"
      Application.put_env(:good_job, :config, %{
        repo: GoodJob.TestRepo,
        queues: "ex.queue1:2;ex.queue2:1;*",
        max_threads: 5
      })

      {:ok, pid} = Supervisor.start_link([])
      assert Process.alive?(pid)

      # Verify children were created (should have 3 schedulers)
      children = :supervisor.which_children(pid)
      assert length(children) == 3

      GenServer.stop(pid, :normal)
    end

    test "parses ordered queues with concurrency" do
      # Test: "+queue1,queue2:5"
      Application.put_env(:good_job, :config, %{
        repo: GoodJob.TestRepo,
        queues: "+ex.queue1,ex.queue2:5",
        max_processes: 3
      })

      {:ok, pid} = Supervisor.start_link([])
      assert Process.alive?(pid)

      # Should create one scheduler for the ordered queue pool
      children = :supervisor.which_children(pid)
      assert length(children) == 1

      GenServer.stop(pid, :normal)
    end

    test "parses excluded queues with concurrency" do
      # Test: "-queue1,queue2:2"
      Application.put_env(:good_job, :config, %{
        repo: GoodJob.TestRepo,
        queues: "-ex.queue1,ex.queue2:2",
        max_processes: 3
      })

      {:ok, pid} = Supervisor.start_link([])
      assert Process.alive?(pid)

      # Should create one scheduler for the excluded queue pool
      children = :supervisor.which_children(pid)
      assert length(children) == 1

      GenServer.stop(pid, :normal)
    end
  end
end
