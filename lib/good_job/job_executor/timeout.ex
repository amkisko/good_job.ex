defmodule GoodJob.JobExecutor.Timeout do
  @moduledoc """
  Handles job execution with timeout.
  """

  alias GoodJob.{Errors, Telemetry}

  @doc """
  Executes a job function with a timeout.
  """
  def perform_with_timeout(perform_fun, job, timeout_ms) when is_function(perform_fun, 0) do
    start_time = System.monotonic_time()
    # Trap exits to handle task exceptions properly
    old_trap_exit = Process.flag(:trap_exit, true)

    try do
      task = Task.async(perform_fun)

      case Task.yield(task, timeout_ms) do
        {:ok, result} ->
          result

        nil ->
          # Task didn't complete in time, shutdown and check for timeout
          case Task.shutdown(task) do
            {:ok, result} ->
              result

            {:exit, {%_exception{} = error, stacktrace}} when is_list(stacktrace) ->
              # Task raised an exception - re-raise it
              Telemetry.execute_timeout(job, timeout_ms, start_time)
              reraise error, stacktrace

            {:exit, reason} ->
              Telemetry.execute_timeout(job, timeout_ms, start_time)
              raise "Job process exited: #{inspect(reason)}"

            nil ->
              Telemetry.execute_timeout(job, timeout_ms, start_time)

              raise %Errors.JobTimeoutError{
                message: "Job #{job.id} timed out after #{timeout_ms}ms",
                job_id: job.id,
                timeout_ms: timeout_ms
              }
          end

        {:exit, {%_exception{} = error, stacktrace}} when is_list(stacktrace) ->
          # Task raised an exception - re-raise it
          Telemetry.execute_timeout(job, timeout_ms, start_time)
          reraise error, stacktrace

        {:exit, reason} ->
          Telemetry.execute_timeout(job, timeout_ms, start_time)
          raise "Job process exited: #{inspect(reason)}"
      end
    after
      # Restore original trap_exit flag
      Process.flag(:trap_exit, old_trap_exit)

      # Check for any exit messages that might have been trapped
      receive do
        {:EXIT, _pid, {%_exception{} = error, stacktrace}} when is_list(stacktrace) ->
          Telemetry.execute_timeout(job, timeout_ms, start_time)
          reraise error, stacktrace

        {:EXIT, _pid, :normal} ->
          # Normal exit, ignore
          :ok

        {:EXIT, _pid, reason} ->
          Telemetry.execute_timeout(job, timeout_ms, start_time)
          raise "Job process exited: #{inspect(reason)}"
      after
        0 ->
          :ok
      end
    end
  end

  @doc """
  Gets the timeout for a job module.
  """
  def get_job_timeout(job_module, _job) do
    if function_exported?(job_module, :__good_job_timeout__, 0) do
      job_module.__good_job_timeout__()
    else
      :infinity
    end
  end
end
