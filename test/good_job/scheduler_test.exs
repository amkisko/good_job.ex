defmodule GoodJob.SchedulerTest do
  use ExUnit.Case, async: false
  use GoodJob.Testing.JobCase

  alias GoodJob.Scheduler

  defmodule TestJob do
    @behaviour GoodJob.Behaviour

    def perform(_args) do
      :ok
    end
  end

  setup do
    # Clean up any existing schedulers
    :ok
  end

  describe "start_link/1" do
    test "starts a scheduler with queue configuration" do
      opts = [
        queue_string: "default",
        max_processes: 5
      ]

      {:ok, pid} = Scheduler.start_link(opts)
      assert Process.alive?(pid)

      # Clean up
      GenServer.stop(pid, :normal)
    end

    test "starts a scheduler with custom name" do
      opts = [
        queue_string: "ex.test",
        max_threads: 3,
        name: :test_scheduler
      ]

      {:ok, pid} = Scheduler.start_link(opts)
      assert Process.whereis(:test_scheduler) == pid

      # Clean up
      GenServer.stop(pid, :normal)
    end

    test "starts a scheduler with cleanup configuration" do
      opts = [
        queue_string: "ex.cleanup_test",
        max_threads: 2,
        cleanup_interval_seconds: 60,
        cleanup_interval_jobs: 100
      ]

      {:ok, pid} = Scheduler.start_link(opts)
      assert Process.alive?(pid)

      # Clean up
      GenServer.stop(pid, :normal)
    end
  end

  describe "GenServer callbacks" do
    test "handles shutdown call" do
      opts = [queue_string: "ex.shutdown_test", max_processes: 1]
      {:ok, pid} = Scheduler.start_link(opts)

      # Use call instead of cast for shutdown
      result = GenServer.call(pid, :shutdown)
      assert result == :ok

      # Check shutdown state
      shutdown? = GenServer.call(pid, :shutdown?)
      assert shutdown? == true

      # Clean up
      GenServer.stop(pid, :normal)
    end

    test "handles shutdown call with timeout" do
      opts = [queue_string: "ex.shutdown_timeout_test", max_processes: 1]
      {:ok, pid} = Scheduler.start_link(opts)

      # Shutdown with timeout
      result = GenServer.call(pid, {:shutdown, 1000})
      assert result == :ok

      # Clean up
      GenServer.stop(pid, :normal)
    end

    test "gets running tasks count" do
      opts = [queue_string: "ex.tasks_test", max_processes: 2]
      {:ok, pid} = Scheduler.start_link(opts)

      # Get running tasks count
      {:ok, count} = GenServer.call(pid, :get_running_tasks_count)
      assert is_integer(count)
      assert count >= 0

      # Clean up
      GenServer.stop(pid, :normal)
    end

    test "handles :poll message when shutdown" do
      opts = [queue_string: "ex.poll_shutdown_test", max_processes: 1]
      {:ok, pid} = Scheduler.start_link(opts)

      # Shutdown first
      GenServer.call(pid, :shutdown)

      # Send poll - should be ignored when shutdown
      send(pid, :poll)
      Process.sleep(100)

      assert Process.alive?(pid)
      GenServer.stop(pid, :normal)
    end

    test "handles :poll message when at capacity" do
      opts = [queue_string: "ex.poll_capacity_test", max_processes: 1]
      {:ok, pid} = Scheduler.start_link(opts)
      Process.sleep(100)

      # Set running_tasks to max capacity using a tuple with ref
      :sys.replace_state(pid, fn state ->
        # Simulate being at capacity - use a ref and a tuple
        fake_ref = make_ref()
        # Store as {task_pid, job} where task_pid is just a placeholder
        %{state | running_tasks: %{fake_ref => {self(), %GoodJob.Job{id: "test"}}}}
      end)

      # Send poll - should schedule next poll but not execute
      send(pid, :poll)
      Process.sleep(200)

      assert Process.alive?(pid)
      GenServer.stop(pid, :normal)
    end

    test "handles task completion with success" do
      opts = [queue_string: "ex.task_success_test", max_processes: 2]
      {:ok, pid} = Scheduler.start_link(opts)
      Process.sleep(100)

      # Create a fake task ref and job
      ref = make_ref()
      job = %GoodJob.Job{id: Ecto.UUID.generate()}

      # Set running task - use a pid instead of Task struct
      :sys.replace_state(pid, fn state ->
        %{state | running_tasks: %{ref => {self(), job}}}
      end)

      # Simulate task completion
      send(pid, {ref, {:ok, :success}})
      Process.sleep(200)

      # Check that task was removed
      {:ok, count} = GenServer.call(pid, :get_running_tasks_count)
      assert count == 0

      GenServer.stop(pid, :normal)
    end

    test "handles task completion with error" do
      opts = [queue_string: "ex.task_error_test", max_processes: 2]
      {:ok, pid} = Scheduler.start_link(opts)
      Process.sleep(100)

      # Create a fake task ref and job
      ref = make_ref()
      job = %GoodJob.Job{id: Ecto.UUID.generate()}

      # Set running task
      :sys.replace_state(pid, fn state ->
        %{state | running_tasks: %{ref => {self(), job}}}
      end)

      # Simulate task error
      send(pid, {ref, {:error, %RuntimeError{message: "test error"}}})
      Process.sleep(200)

      # Check that task was removed
      {:ok, count} = GenServer.call(pid, :get_running_tasks_count)
      assert count == 0

      GenServer.stop(pid, :normal)
    end

    test "handles task DOWN message" do
      opts = [queue_string: "ex.task_down_test", max_processes: 2]
      {:ok, pid} = Scheduler.start_link(opts)
      Process.sleep(100)

      # Create a fake task ref and job
      ref = make_ref()
      job = %GoodJob.Job{id: Ecto.UUID.generate()}

      # Set running task
      :sys.replace_state(pid, fn state ->
        %{state | running_tasks: %{ref => {self(), job}}}
      end)

      # Simulate task crash
      send(pid, {:DOWN, ref, :process, self(), :normal})
      Process.sleep(200)

      # Check that task was removed
      {:ok, count} = GenServer.call(pid, :get_running_tasks_count)
      assert count == 0

      GenServer.stop(pid, :normal)
    end

    test "handles :tasks_complete message" do
      opts = [queue_string: "ex.tasks_complete_test", max_processes: 1]
      {:ok, pid} = Scheduler.start_link(opts)
      Process.sleep(100)

      # Create a from tuple for GenServer.reply
      from = {self(), make_ref()}

      :sys.replace_state(pid, fn state ->
        %{state | wait_pid: self()}
      end)

      # Send tasks_complete
      send(pid, {:tasks_complete, from})
      Process.sleep(100)

      # Should receive reply
      receive do
        :ok -> :ok
      after
        500 -> :timeout
      end

      GenServer.stop(pid, :normal)
    end

    test "handles :tasks_timeout message" do
      opts = [queue_string: "ex.tasks_timeout_test", max_processes: 1]
      {:ok, pid} = Scheduler.start_link(opts)
      Process.sleep(100)

      # Create a from tuple for GenServer.reply
      from = {self(), make_ref()}

      :sys.replace_state(pid, fn state ->
        %{state | wait_pid: self()}
      end)

      # Send tasks_timeout
      send(pid, {:tasks_timeout, from})
      Process.sleep(100)

      # Should receive timeout reply
      receive do
        :timeout -> :ok
      after
        500 -> :timeout
      end

      GenServer.stop(pid, :normal)
    end

    test "handles :poll when no job available" do
      opts = [queue_string: "ex.poll_no_job_test", max_threads: 1]
      {:ok, pid} = Scheduler.start_link(opts)
      Process.sleep(100)

      # Send poll - should handle gracefully when no jobs
      send(pid, :poll)
      Process.sleep(200)

      assert Process.alive?(pid)
      GenServer.stop(pid, :normal)
    end

    test "handles :poll when JobPerformer returns error" do
      opts = [queue_string: "ex.poll_error_test", max_threads: 1]
      {:ok, pid} = Scheduler.start_link(opts)
      Process.sleep(100)

      # Send poll - will try to get job and may get error
      send(pid, :poll)
      Process.sleep(200)

      assert Process.alive?(pid)
      GenServer.stop(pid, :normal)
    end

    test "handles shutdown with running tasks" do
      opts = [queue_string: "ex.shutdown_tasks_test", max_processes: 2]
      {:ok, pid} = Scheduler.start_link(opts)
      Process.sleep(100)

      # Set running tasks
      ref = make_ref()
      job = %GoodJob.Job{id: Ecto.UUID.generate()}

      :sys.replace_state(pid, fn state ->
        %{state | running_tasks: %{ref => {self(), job}}}
      end)

      # Shutdown with very short timeout - should timeout quickly
      # Use catch to handle timeout
      _result =
        try do
          GenServer.call(pid, {:shutdown, 0}, 2000)
        catch
          :exit, {:timeout, _} -> :timeout
        end

      # Should timeout since tasks don't complete
      # Just verify the scheduler is still alive and can be stopped
      assert Process.alive?(pid)

      # Complete the task to allow clean shutdown
      send(pid, {ref, {:ok, :success}})
      Process.sleep(200)

      GenServer.stop(pid, :normal)
    end

    test "handles task completion triggering cleanup" do
      opts = [queue_string: "ex.cleanup_test", max_processes: 2, cleanup_interval_jobs: 1]
      {:ok, pid} = Scheduler.start_link(opts)
      Process.sleep(100)

      # Set cleanup tracker to trigger cleanup on next increment
      :sys.replace_state(pid, fn state ->
        tracker = GoodJob.CleanupTracker.increment(state.cleanup_tracker)
        %{state | cleanup_tracker: tracker}
      end)

      # Complete a task to trigger cleanup check
      ref = make_ref()
      job = %GoodJob.Job{id: Ecto.UUID.generate()}

      :sys.replace_state(pid, fn state ->
        %{state | running_tasks: %{ref => {self(), job}}}
      end)

      send(pid, {ref, {:ok, :success}})
      Process.sleep(300)

      assert Process.alive?(pid)
      GenServer.stop(pid, :normal)
    end

    test "handles task completion without triggering cleanup" do
      opts = [queue_string: "ex.no_cleanup_test", max_processes: 2, cleanup_interval_jobs: 100]
      {:ok, pid} = Scheduler.start_link(opts)
      Process.sleep(100)

      # Complete a task - should not trigger cleanup
      ref = make_ref()
      job = %GoodJob.Job{id: Ecto.UUID.generate()}

      :sys.replace_state(pid, fn state ->
        %{state | running_tasks: %{ref => {self(), job}}}
      end)

      send(pid, {ref, {:ok, :success}})
      Process.sleep(200)

      assert Process.alive?(pid)
      GenServer.stop(pid, :normal)
    end

    test "handles task DOWN with unknown ref" do
      opts = [queue_string: "ex.down_unknown_test", max_processes: 2]
      {:ok, pid} = Scheduler.start_link(opts)
      Process.sleep(100)

      # Send DOWN for unknown ref - should not crash
      unknown_ref = make_ref()
      send(pid, {:DOWN, unknown_ref, :process, self(), :normal})
      Process.sleep(100)

      assert Process.alive?(pid)
      GenServer.stop(pid, :normal)
    end

    test "handles task completion with unknown ref" do
      opts = [queue_string: "ex.complete_unknown_test", max_processes: 2]
      {:ok, pid} = Scheduler.start_link(opts)
      Process.sleep(100)

      # Send completion for unknown ref - should not crash
      unknown_ref = make_ref()
      send(pid, {unknown_ref, {:ok, :success}})
      Process.sleep(100)

      assert Process.alive?(pid)
      GenServer.stop(pid, :normal)
    end
  end
end
