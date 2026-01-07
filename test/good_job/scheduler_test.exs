defmodule GoodJob.SchedulerTest do
  use ExUnit.Case, async: true

  alias GoodJob.CleanupTracker
  alias GoodJob.Scheduler

  test "poll returns early when shutdown is true" do
    cleanup_tracker = CleanupTracker.new(cleanup_interval_seconds: false, cleanup_interval_jobs: false)

    state = %{
      queue_string: "default",
      max_processes: 1,
      task_supervisor: self(),
      running_tasks: %{},
      shutdown: true,
      cleanup_tracker: cleanup_tracker,
      wait_pid: nil
    }

    assert {:noreply, ^state} = Scheduler.handle_info(:poll, state)
  end

  test "task completion removes running task and schedules next poll" do
    cleanup_tracker = CleanupTracker.new(cleanup_interval_seconds: false, cleanup_interval_jobs: false)
    ref = make_ref()
    task = %Task{ref: ref, pid: self(), owner: self(), mfa: {Kernel, :self, 0}}
    job = %GoodJob.Job{id: "job-id"}

    state = %{
      queue_string: "default",
      max_processes: 1,
      task_supervisor: self(),
      running_tasks: %{ref => {task, job}},
      shutdown: false,
      cleanup_tracker: cleanup_tracker,
      wait_pid: nil
    }

    assert {:noreply, new_state} = Scheduler.handle_info({ref, {:ok, :ok}}, state)
    assert new_state.running_tasks == %{}
  end
end
