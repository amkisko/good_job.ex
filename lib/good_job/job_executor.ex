defmodule GoodJob.JobExecutor do
  @moduledoc """
  Executes jobs by deserializing and calling the perform function.

  Handles:
  - Job deserialization
  - Job execution
  - Error handling
  - Retry logic
  - Execution tracking
  """

  require Logger
  import Ecto.Query
  alias GoodJob.{Concurrency, Errors, Execution, Job, Repo, Telemetry, Utils}
  alias GoodJob.JobExecutor.{ResultHandler, Timeout}
  alias GoodJob.Protocol.Deserializer

  @doc """
  Executes a job inline (synchronously in the current process).
  """
  @spec execute_inline(GoodJob.Job.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def execute_inline(job, _opts \\ []) do
    job =
      if is_nil(job.performed_at) do
        now = DateTime.utc_now()
        repo = Repo.repo()

        case repo.update(Job.changeset(job, %{performed_at: now})) do
          {:ok, updated_job} -> updated_job
          {:error, _} -> job
        end
      else
        job
      end

    execute(job, nil, [])
  end

  @doc """
  Executes a job and handles the result.
  """
  @spec execute(GoodJob.Job.t(), String.t() | nil, keyword()) :: {:ok, term()} | {:error, term()}
  def execute(job, lock_id, _opts \\ []) do
    repo = Repo.repo()
    start_time = System.monotonic_time()
    process_id = lock_id
    job_performed_at = DateTime.utc_now()

    Telemetry.execute_start(job)

    if not is_nil(job.finished_at) do
      raise Errors.PreviouslyPerformedError, "Cannot perform a job that has already been performed"
    end

    try do
      if job.concurrency_key do
        config = get_concurrency_config(job)

        case Concurrency.check_perform_limit(job.concurrency_key, job.active_job_id, config) do
          {:ok, :ok} ->
            :ok

          {:ok, {:error, :limit_exceeded}} ->
            raise %Errors.ConcurrencyExceededError{
              message: "Concurrency limit exceeded for key: #{job.concurrency_key}",
              concurrency_key: job.concurrency_key
            }

          {:ok, {:error, :throttle_exceeded}} ->
            raise %Errors.ThrottleExceededError{
              message: "Throttle limit exceeded for key: #{job.concurrency_key}",
              concurrency_key: job.concurrency_key
            }

          error ->
            raise %Errors.ConfigurationError{
              message: "Concurrency check failed: #{inspect(error)}"
            }
        end
      end

      existing_performed_at = job.performed_at

      if existing_performed_at do
        interrupt_error_string =
          Utils.format_error(
            Errors.InterruptError.exception("Interrupted after starting perform at '#{existing_performed_at}'")
          )

        interrupt_duration = format_duration(System.monotonic_time() - start_time)

        repo.update_all(
          from(e in Execution,
            where: e.active_job_id == ^job.active_job_id,
            where: is_nil(e.finished_at),
            where: not is_nil(e.inserted_at)
          ),
          set: [
            error: interrupt_error_string,
            finished_at: job_performed_at,
            error_event: 0,
            duration: interrupt_duration
          ]
        )
      end

      {:ok, {execution, fresh_job}} =
        repo.transaction(fn ->
          fresh_job = repo.get!(Job, job.id)
          normalized_process_id = normalize_process_id(process_id)

          execution_attrs = %{
            active_job_id: fresh_job.active_job_id,
            job_class: fresh_job.job_class,
            queue_name: fresh_job.queue_name,
            serialized_params: fresh_job.serialized_params,
            scheduled_at: fresh_job.scheduled_at || fresh_job.inserted_at,
            process_id: normalized_process_id
          }

          job_attrs = %{
            performed_at: job_performed_at,
            executions_count: (fresh_job.executions_count || 0) + 1,
            locked_by_id: normalized_process_id,
            locked_at: job_performed_at
          }

          execution =
            %Execution{}
            |> Execution.changeset(execution_attrs)
            |> repo.insert!()

          fresh_job =
            fresh_job
            |> Job.changeset(job_attrs)
            |> repo.update!()

          {execution, fresh_job}
        end)

      job_module = Deserializer.deserialize_job_module(fresh_job.job_class, fresh_job.serialized_params)
      raw_args = Deserializer.deserialize_args(fresh_job.serialized_params)
      normalized_args = Deserializer.normalize_args_for_elixir(job_module, raw_args, fresh_job)

      final_args =
        case GoodJob.JobCallbacks.before_perform(job_module, normalized_args, fresh_job) do
          {:ok, modified_args} -> modified_args
          {:error, reason} -> raise "before_perform callback returned error: #{inspect(reason)}"
        end

      timeout = Timeout.get_job_timeout(job_module, fresh_job)

      result =
        try do
          raw_result =
            Timeout.perform_with_timeout(
              fn -> perform_job(job_module, final_args, fresh_job) end,
              fresh_job,
              timeout
            )

          normalized_result = ResultHandler.normalize_result(raw_result)

          case normalized_result do
            :ok ->
              GoodJob.JobCallbacks.after_perform(job_module, final_args, fresh_job, :ok)

            {:ok, value} ->
              GoodJob.JobCallbacks.after_perform(job_module, final_args, fresh_job, value)

            _ ->
              :ok
          end

          normalized_result
        rescue
          error ->
            stacktrace = __STACKTRACE__
            error_class = GoodJob.Errors.classify_error(error)
            {:exception, error, error_class, stacktrace}
        catch
          kind, reason ->
            stacktrace = __STACKTRACE__
            error = Exception.normalize(kind, reason, stacktrace)
            {:exception, error, :unhandled, stacktrace}
        end

      {final_result, handled_error, unhandled_error, error_event, stacktrace_for_backtrace} =
        case result do
          {:exception, error, _error_class, stacktrace} ->
            if before_perform_error?(error) do
              reraise error, stacktrace
            end

            {nil, nil, error, :unhandled, stacktrace}

          :ok ->
            {:ok, nil, nil, nil, []}

          {:ok, _value} = ok_result ->
            {ok_result, nil, nil, nil, []}

          {:error, reason} = error_result ->
            {error_result, reason, nil, :handled, []}

          {:cancel, reason} = cancel_result ->
            {cancel_result, reason, nil, :cancelled, []}

          :discard ->
            {:discard, "Job discarded", nil, :discarded, []}

          {:discard, reason} = discard_result ->
            {discard_result, reason, nil, :discarded, []}

          {:snooze, _seconds} = snooze_result ->
            {snooze_result, nil, nil, :snoozed, []}

          other ->
            {other, nil, nil, nil, []}
        end

      ResultHandler.finish_execution(
        fresh_job,
        execution,
        final_result,
        handled_error,
        unhandled_error,
        error_event,
        start_time,
        process_id,
        stacktrace_for_backtrace
      )

      if fresh_job.batch_id do
        GoodJob.Batch.check_completion(fresh_job.batch_id, fresh_job)
      end

      if handled_error || unhandled_error do
        Telemetry.execute_error(fresh_job, handled_error || unhandled_error, start_time)
      else
        Telemetry.execute_success(fresh_job, final_result, start_time)
      end

      if unhandled_error do
        {:error, unhandled_error}
      else
        {:ok, final_result}
      end
    rescue
      error ->
        stacktrace = __STACKTRACE__

        if before_perform_error?(error) do
          Telemetry.execute_exception(job, error, :error, stacktrace, start_time)
          reraise error, stacktrace
        end

        if concurrency_error?(error) do
          Telemetry.execute_exception(job, error, :error, stacktrace, start_time)
          reraise error, stacktrace
        end

        Telemetry.execute_exception(job, error, :error, stacktrace, start_time)
        {:error, error}
    catch
      kind, reason ->
        stacktrace = __STACKTRACE__
        error = Exception.normalize(kind, reason, stacktrace)
        Telemetry.execute_exception(job, error, kind, stacktrace, start_time)
        {:error, error}
    end
  end

  defp normalize_process_id(nil), do: nil

  defp normalize_process_id(process_id) when is_binary(process_id) do
    case Ecto.UUID.cast(process_id) do
      {:ok, uuid} -> uuid
      :error -> nil
    end
  end

  defp normalize_process_id(_), do: nil

  defp format_duration(duration_nanoseconds) do
    total_microseconds = div(duration_nanoseconds, 1_000)
    secs = div(total_microseconds, 1_000_000)
    microsecs = rem(total_microseconds, 1_000_000)
    %Postgrex.Interval{months: 0, days: 0, secs: secs, microsecs: microsecs}
  end

  defp perform_job(module, args, _job) do
    if function_exported?(module, :perform, 1) do
      module.perform(args)
    else
      raise "Job module #{inspect(module)} does not implement perform/1"
    end
  end

  defp before_perform_error?(%RuntimeError{message: message}) when is_binary(message) do
    String.contains?(message, "before_perform callback returned error") ||
      String.contains?(message, "does not implement perform/1")
  end

  defp before_perform_error?(_), do: false

  defp concurrency_error?(%Errors.ConcurrencyExceededError{}), do: true
  defp concurrency_error?(%Errors.ThrottleExceededError{}), do: true
  defp concurrency_error?(_), do: false

  defp get_concurrency_config(job) do
    config_from_params = extract_concurrency_config_from_params(job.serialized_params)
    job_module = Deserializer.deserialize_job_module(job.job_class, job.serialized_params)

    config_from_module =
      if function_exported?(job_module, :good_job_concurrency_config, 0) do
        job_module.good_job_concurrency_config()
      else
        []
      end

    Keyword.merge(config_from_params, config_from_module)
  end

  defp extract_concurrency_config_from_params(serialized_params) when is_map(serialized_params) do
    []
  end

  defp extract_concurrency_config_from_params(_), do: []
end
