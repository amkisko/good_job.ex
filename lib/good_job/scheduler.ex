defmodule GoodJob.Scheduler do
  @moduledoc """
  GenServer that schedules and executes jobs for a specific queue configuration.

  Each scheduler manages a pool of workers that execute jobs from the queue.
  """

  use GenServer
  require Logger

  alias GoodJob.{
    CleanupTracker,
    Config,
    JobPerformer,
    ProcessTracker,
    Telemetry
  }

  # Conditional logging helper for test environment
  if Code.ensure_loaded?(Mix) do
    defp should_log_errors? do
      case {Mix.env(), System.get_env("DEBUG")} do
        {:test, "1"} -> true
        {:test, _} -> false
        _ -> true
      end
    end
  else
    defp should_log_errors?, do: true
  end

  @doc """
  Starts a scheduler for the given queue configuration.
  """
  def start_link(opts) do
    queue_string = Keyword.fetch!(opts, :queue_string)
    max_processes = Keyword.get(opts, :max_processes, Config.max_processes())
    cleanup_interval_seconds = Keyword.get(opts, :cleanup_interval_seconds, Config.cleanup_interval_seconds())
    cleanup_interval_jobs = Keyword.get(opts, :cleanup_interval_jobs, Config.cleanup_interval_jobs())
    name = Keyword.get(opts, :name, scheduler_name(queue_string))

    GenServer.start_link(
      __MODULE__,
      {queue_string, max_processes, cleanup_interval_seconds, cleanup_interval_jobs},
      name: name
    )
  end

  defp scheduler_name(queue_string) do
    {:via, Registry, {GoodJob.Registry, {:scheduler, queue_string}}}
  end

  @impl true
  def init({queue_string, max_processes, cleanup_interval_seconds, cleanup_interval_jobs}) do
    # Start task supervisor for job execution
    task_supervisor =
      case Task.Supervisor.start_link(name: task_supervisor_name(queue_string)) do
        {:ok, pid} -> pid
        {:error, {:already_started, pid}} -> pid
      end

    # Initialize cleanup tracker
    cleanup_tracker =
      CleanupTracker.new(
        cleanup_interval_seconds: cleanup_interval_seconds,
        cleanup_interval_jobs: cleanup_interval_jobs
      )

    state = %{
      queue_string: queue_string,
      max_processes: max_processes,
      task_supervisor: task_supervisor,
      running_tasks: %{},
      shutdown: false,
      cleanup_tracker: cleanup_tracker,
      wait_pid: nil
    }

    # Register with Poller
    case Process.whereis(GoodJob.Poller) do
      nil ->
        # Poller not started yet, will register later
        :ok

      _poller_pid ->
        GoodJob.Poller.add_recipient(self())
    end

    schedule_poll()
    {:ok, state}
  end

  @impl true
  def handle_info(:poll, state) do
    Telemetry.scheduler_poll()

    if state.shutdown do
      {:noreply, state}
    else
      if map_size(state.running_tasks) < state.max_processes do
        lock_id = ProcessTracker.id_for_lock()

        case JobPerformer.perform_next(state.queue_string, lock_id) do
          {:ok, nil} ->
            schedule_poll(Config.poll_interval() * 1000)
            {:noreply, state}

          {:ok, job} ->
            task =
              Task.Supervisor.async_nolink(state.task_supervisor, fn ->
                case GoodJob.JobExecutor.execute(job, lock_id) do
                  {:ok, result} -> {:ok, result}
                  {:error, error} -> {:error, error}
                end
              end)

            running_tasks = Map.put(state.running_tasks, task.ref, {task, job})

            if map_size(running_tasks) < state.max_processes do
              schedule_poll(0)
            else
              schedule_poll(Config.poll_interval() * 1000)
            end

            {:noreply, %{state | running_tasks: running_tasks}}

          {:error, error} ->
            Logger.error("Error performing job: #{inspect(error)}")
            schedule_poll(Config.poll_interval() * 1000)
            {:noreply, state}
        end
      else
        schedule_poll(Config.poll_interval() * 1000)
        {:noreply, state}
      end
    end
  end

  @impl true
  def handle_info({ref, result}, state) when is_reference(ref) do
    case Map.pop(state.running_tasks, ref) do
      {nil, _} ->
        {:noreply, state}

      {{_task, job}, running_tasks} ->
        handle_job_completion(job, result)
        cleanup_tracker = CleanupTracker.increment(state.cleanup_tracker)

        state =
          if CleanupTracker.cleanup?(cleanup_tracker) do
            trigger_cleanup(state)
            %{state | cleanup_tracker: CleanupTracker.reset(cleanup_tracker)}
          else
            %{state | cleanup_tracker: cleanup_tracker}
          end

        if map_size(running_tasks) < state.max_processes do
          schedule_poll(0)
        end

        {:noreply, %{state | running_tasks: running_tasks}}
    end
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, reason}, state) do
    case Map.pop(state.running_tasks, ref) do
      {nil, _} ->
        {:noreply, state}

      {{_task, job}, running_tasks} ->
        if should_log_errors?() do
          Logger.error("Job task crashed: #{inspect(reason)}")
        end

        handle_job_error(job, reason)

        if map_size(running_tasks) < state.max_processes do
          schedule_poll(0)
        end

        {:noreply, %{state | running_tasks: running_tasks}}
    end
  end

  @impl true
  def handle_info({:tasks_complete, from}, state) do
    GenServer.reply(from, :ok)
    {:noreply, %{state | wait_pid: nil}}
  end

  @impl true
  def handle_info({:tasks_timeout, from}, state) do
    GenServer.reply(from, :timeout)
    {:noreply, %{state | wait_pid: nil}}
  end

  @impl true
  def handle_call({:shutdown, timeout}, from, state) do
    # Mark as shutting down
    state = %{state | shutdown: true}

    # Wait for running tasks to complete
    if map_size(state.running_tasks) == 0 do
      {:reply, :ok, state}
    else
      # Start async wait process
      wait_pid = spawn(fn -> wait_for_tasks(state.running_tasks, timeout, from, self()) end)
      {:noreply, %{state | wait_pid: wait_pid}}
    end
  end

  def handle_call(:shutdown, from, state) do
    # Default timeout from config
    timeout = Config.shutdown_timeout()
    handle_call({:shutdown, timeout}, from, state)
  end

  @impl true
  def handle_call(:shutdown?, _from, state) do
    {:reply, state.shutdown, state}
  end

  @impl true
  def handle_call(:get_running_tasks_count, _from, state) do
    {:reply, {:ok, map_size(state.running_tasks)}, state}
  end

  defp wait_for_tasks(running_tasks, timeout, from, scheduler_pid) do
    wait_timeout_ms =
      case timeout do
        -1 -> :infinity
        0 -> 0
        t when t > 0 -> t * 1000
      end

    result = wait_for_tasks_loop(running_tasks, wait_timeout_ms, scheduler_pid)

    case result do
      :ok -> send(scheduler_pid, {:tasks_complete, from})
      :timeout -> send(scheduler_pid, {:tasks_timeout, from})
    end
  end

  @doc false
  def wait_for_tasks_loop(running_tasks, timeout_ms, scheduler_pid) do
    if map_size(running_tasks) == 0 do
      :ok
    else
      # Poll the scheduler to check if tasks completed
      check_interval = 500

      remaining_timeout =
        case timeout_ms do
          :infinity -> :infinity
          0 -> 0
          t when t > 0 -> max(0, t - check_interval)
        end

      case GenServer.call(scheduler_pid, :get_running_tasks_count, check_interval) do
        {:ok, 0} ->
          :ok

        {:ok, _count} when remaining_timeout == 0 ->
          :timeout

        {:ok, _count} when remaining_timeout == :infinity ->
          Process.sleep(check_interval)
          wait_for_tasks_loop(running_tasks, remaining_timeout, scheduler_pid)

        {:ok, _count} ->
          Process.sleep(check_interval)
          wait_for_tasks_loop(running_tasks, remaining_timeout, scheduler_pid)

        _ ->
          if remaining_timeout == 0 do
            :timeout
          else
            Process.sleep(check_interval)
            wait_for_tasks_loop(running_tasks, remaining_timeout, scheduler_pid)
          end
      end
    end
  end

  defp schedule_poll(delay \\ 0) do
    Process.send_after(self(), :poll, delay)
  end

  defp task_supervisor_name(queue_string) do
    {:via, Registry, {GoodJob.Registry, {:task_supervisor, queue_string}}}
  end

  defp handle_job_completion(_job, {:ok, _result}) do
    # Job completed successfully
    :ok
  end

  defp handle_job_completion(job, {:error, error}) do
    # Job failed, error handling is done in JobExecutor
    if should_log_errors?() do
      Logger.error("Job #{job.id} failed: #{inspect(error)}")
    end

    :ok
  end

  defp handle_job_error(job, reason) do
    # Task crashed, create error execution
    if should_log_errors?() do
      Logger.error("Job task crashed for job #{job.id}: #{inspect(reason)}")
    end

    :ok
  end

  defp trigger_cleanup(_state) do
    # Trigger cleanup in background
    Task.start(fn ->
      try do
        Telemetry.cleanup_triggered(:scheduler)
        GoodJob.Cleanup.cleanup_preserved_jobs()
      rescue
        e ->
          Logger.error("Cleanup failed: #{inspect(e)}")
      end
    end)
  end
end
