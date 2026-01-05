defmodule GoodJob.JobExecutor.ResultHandler do
  @moduledoc """
  Handles job execution results and state updates.
  """

  require Logger
  import Ecto.Query
  alias Ecto.Multi
  alias GoodJob.{Execution, Job, Repo, Utils}

  @doc """
  Normalizes job result for consistent handling.
  """
  @spec normalize_result(term()) ::
          :ok
          | {:ok, term()}
          | {:error, term()}
          | {:cancel, term()}
          | :discard
          | {:discard, term()}
          | {:snooze, integer()}
          | term()
  def normalize_result(:ok), do: :ok
  def normalize_result({:ok, _value} = result), do: result
  def normalize_result({:error, _reason} = result), do: result
  def normalize_result({:cancel, _reason} = result), do: result
  def normalize_result(:discard), do: :discard
  def normalize_result({:discard, _reason} = result), do: result
  def normalize_result({:snooze, seconds} = result) when is_integer(seconds), do: result
  def normalize_result(other), do: other

  @doc """
  Handles successful job execution.
  """
  @spec handle_success(GoodJob.Job.t(), term(), integer(), String.t() | nil) :: :ok | {:error, Ecto.Changeset.t()}
  def handle_success(job, _result, start_time, process_id) do
    duration = System.monotonic_time() - start_time
    now = DateTime.utc_now()

    repo = Repo.repo()
    fresh_job = repo.get!(Job, job.id)
    executions_count = (fresh_job.executions_count || 0) + 1

    Multi.new()
    |> Multi.update(:job, update_job_success(fresh_job, now, executions_count))
    |> Multi.insert(:execution, create_execution(fresh_job, nil, now, duration, process_id))
    |> repo.transaction()
    |> case do
      {:ok, _} ->
        GoodJob.PubSub.broadcast(:job_completed, fresh_job.id)
        :ok

      {:error, _name, changeset, _changes} ->
        Logger.error("Failed to update job #{fresh_job.id} on success: #{inspect(changeset.errors)}")
        {:error, changeset}
    end
  end

  @doc """
  Handles job execution error with retry logic.
  """
  @spec handle_error(GoodJob.Job.t(), term(), integer(), String.t() | nil, list()) :: :ok | {:error, Ecto.Changeset.t()}
  def handle_error(job, reason, start_time, process_id, stacktrace \\ []) do
    duration = System.monotonic_time() - start_time
    now = DateTime.utc_now()

    repo = Repo.repo()
    # Reload job to ensure we have the latest state
    fresh_job = repo.get!(Job, job.id)
    executions_count = (fresh_job.executions_count || 0) + 1

    max_attempts = get_max_attempts(fresh_job)
    backoff_seconds = calculate_backoff(fresh_job, executions_count)

    {finished_at, scheduled_at} =
      if executions_count >= max_attempts do
        {now, nil}
      else
        {nil, DateTime.add(now, backoff_seconds, :second)}
      end

    # Build changeset - update_job_error already uses force_change for finished_at
    changeset = update_job_error(fresh_job, reason, finished_at, executions_count, scheduled_at)

    # For retries, ensure finished_at is explicitly nil in changes
    # Double-check that force_change worked
    changeset =
      if is_nil(finished_at) do
        # Ensure finished_at is nil in changes
        case Map.get(changeset.changes, :finished_at) do
          nil ->
            # Not in changes, force it
            Ecto.Changeset.force_change(changeset, :finished_at, nil)

          _value ->
            # Already in changes, make sure it's nil
            changeset
            |> Ecto.Changeset.delete_change(:finished_at)
            |> Ecto.Changeset.force_change(:finished_at, nil)
        end
      else
        changeset
      end

    # Build Multi
    multi = Multi.new()

    # For retries, use Multi.run with update_all (changeset approach doesn't work reliably for nil)
    # For exhausted jobs, use the changeset
    multi =
      if is_nil(finished_at) do
        # Use update_all to ensure finished_at is cleared (changeset doesn't work reliably)
        import Ecto.Query

        updated_serialized_params =
          if is_map(fresh_job.serialized_params) do
            GoodJob.Protocol.Serialization.update_executions(fresh_job.serialized_params, executions_count)
          else
            fresh_job.serialized_params
          end

        Multi.run(multi, :update_job, fn repo_fn, _changes ->
          {count, _} =
            repo_fn.update_all(
              from(j in Job, where: j.id == ^fresh_job.id),
              set: [
                finished_at: nil,
                performed_at: nil,
                scheduled_at: scheduled_at,
                error: format_error(reason),
                executions_count: executions_count,
                serialized_params: updated_serialized_params,
                locked_by_id: nil,
                locked_at: nil
              ]
            )

          {:ok, count}
        end)
      else
        # For exhausted jobs, use the changeset
        changeset = %{changeset | action: :update}
        Multi.update(multi, :job, changeset)
      end

    multi =
      Multi.insert(
        multi,
        :execution,
        create_execution(fresh_job, reason, finished_at, duration, process_id, stacktrace)
      )

    result = repo.transaction(multi)

    result
    |> case do
      {:ok, _} ->
        # For retries, do a final update_all after transaction to ensure finished_at is cleared
        # This is a safety net in case the transaction update didn't work
        if is_nil(finished_at) do
          import Ecto.Query
          # Reload job to get latest state
          final_job = repo.get(Job, fresh_job.id)

          if final_job && not is_nil(final_job.finished_at) do
            # finished_at is still set, clear it explicitly
            repo.update_all(
              from(j in Job, where: j.id == ^fresh_job.id),
              set: [finished_at: nil, performed_at: nil]
            )
          end
        end

        if finished_at do
          Logger.warning("Job #{fresh_job.id} exhausted after #{executions_count} attempts")
          GoodJob.PubSub.broadcast(:job_exhausted, fresh_job.id)
        else
          GoodJob.PubSub.broadcast(:job_retrying, fresh_job.id)
        end

        :ok

      {:error, _name, changeset, _changes} ->
        Logger.error("Failed to update job #{fresh_job.id} on error: #{inspect(changeset.errors)}")
        {:error, changeset}
    end
  end

  @doc """
  Handles job cancellation.
  """
  def handle_cancel(job, reason, start_time, process_id) do
    duration = System.monotonic_time() - start_time
    now = DateTime.utc_now()

    repo = Repo.repo()
    fresh_job = repo.get!(Job, job.id)

    Multi.new()
    |> Multi.update(:job, update_job_cancel(fresh_job, reason, now))
    |> Multi.insert(:execution, create_execution(fresh_job, reason, now, duration, process_id))
    |> repo.transaction()
    |> case do
      {:ok, _} ->
        GoodJob.PubSub.broadcast(:job_cancelled, fresh_job.id)
        GoodJob.Telemetry.job_cancel(fresh_job, reason, start_time)
        :ok

      {:error, _name, changeset, _changes} ->
        Logger.error("Failed to update job #{fresh_job.id} on cancel: #{inspect(changeset.errors)}")
        {:error, changeset}
    end
  end

  @doc """
  Handles job discard.
  """
  def handle_discard(job, reason, start_time, process_id) do
    duration = System.monotonic_time() - start_time
    now = DateTime.utc_now()

    repo = Repo.repo()
    fresh_job = repo.get!(Job, job.id)

    Multi.new()
    |> Multi.update(:job, update_job_discard(fresh_job, reason, now))
    |> Multi.insert(:execution, create_execution(fresh_job, reason, now, duration, process_id))
    |> repo.transaction()
    |> case do
      {:ok, _} ->
        GoodJob.PubSub.broadcast(:job_discarded, fresh_job.id)
        GoodJob.Telemetry.job_discard(fresh_job, reason, start_time)
        :ok

      {:error, _name, changeset, _changes} ->
        Logger.error("Failed to update job #{fresh_job.id} on discard: #{inspect(changeset.errors)}")
        {:error, changeset}
    end
  end

  @doc """
  Handles job snooze (reschedule for later).
  """
  def handle_snooze(job, seconds, start_time, process_id) do
    duration = System.monotonic_time() - start_time
    now = DateTime.utc_now()
    scheduled_at = DateTime.add(now, seconds, :second)

    repo = Repo.repo()
    fresh_job = repo.get!(Job, job.id)

    Multi.new()
    |> Multi.update(:job, update_job_snooze(fresh_job, scheduled_at))
    |> Multi.insert(:execution, create_execution(fresh_job, nil, nil, duration, process_id))
    |> repo.transaction()
    |> case do
      {:ok, _} ->
        GoodJob.PubSub.broadcast(:job_snoozed, fresh_job.id)
        GoodJob.Telemetry.job_snooze(fresh_job, seconds, start_time)
        :ok

      {:error, _name, changeset, _changes} ->
        Logger.error("Failed to update job #{fresh_job.id} on snooze: #{inspect(changeset.errors)}")
        {:error, changeset}
    end
  end

  defp get_max_attempts(job) do
    job_module =
      try do
        GoodJob.Protocol.Deserializer.deserialize_job_module(job.job_class, job.serialized_params)
      rescue
        _ ->
          nil
      end

    if job_module && function_exported?(job_module, :max_attempts, 0) do
      job_module.max_attempts()
    else
      Application.get_env(:good_job, :max_attempts, 5)
    end
  end

  defp calculate_backoff(job, attempt) do
    job_module = GoodJob.Protocol.Deserializer.deserialize_job_module(job.job_class, job.serialized_params)

    if function_exported?(job_module, :backoff, 1) do
      job_module.backoff(attempt)
    else
      # Default to constant 3 seconds to match Ruby GoodJob's ActiveJob default
      GoodJob.Backoff.constant(attempt)
    end
  end

  defp update_job_success(job, finished_at, executions_count) do
    updated_serialized_params =
      if is_map(job.serialized_params) do
        GoodJob.Protocol.Serialization.update_executions(job.serialized_params, executions_count)
      else
        job.serialized_params
      end

    # Preserve an existing performed_at when present (e.g., execute_inline/2
    # set it before calling execute/3). For jobs executed directly via
    # execute/3 without a prior performed_at, set performed_at to the same
    # timestamp as finished_at so tests can assert that the job was
    # "performed" as part of this execution.
    attrs =
      %{
        finished_at: finished_at,
        error: nil,
        locked_by_id: nil,
        locked_at: nil,
        executions_count: executions_count,
        serialized_params: updated_serialized_params
      }
      |> maybe_put_performed_at(job, finished_at)

    Job.changeset(job, attrs)
  end

  defp maybe_put_performed_at(attrs, %Job{performed_at: nil}, finished_at) do
    Map.put(attrs, :performed_at, finished_at)
  end

  defp maybe_put_performed_at(attrs, _job, _finished_at), do: attrs

  defp update_job_error(job, error, finished_at, executions_count, scheduled_at) do
    updated_serialized_params =
      if is_map(job.serialized_params) do
        GoodJob.Protocol.Serialization.update_executions(job.serialized_params, executions_count)
      else
        job.serialized_params
      end

    base_attrs = %{
      error: format_error(error),
      executions_count: executions_count,
      serialized_params: updated_serialized_params,
      locked_by_id: nil,
      locked_at: nil,
      performed_at: nil
    }

    # Include finished_at and scheduled_at in attrs based on retry vs exhausted
    attrs =
      if finished_at do
        # Exhausted - set finished_at, clear scheduled_at
        Map.merge(base_attrs, %{finished_at: finished_at, scheduled_at: nil})
      else
        # Retry - clear finished_at, set scheduled_at
        Map.merge(base_attrs, %{finished_at: nil, scheduled_at: scheduled_at})
      end

    # Build changeset with all attrs
    changeset = Job.changeset(job, attrs)

    # Always use force_change for finished_at and scheduled_at to ensure they're set correctly
    # For retries, we need to explicitly clear finished_at by removing it from changes first,
    # then forcing it to nil to ensure it's updated in the database
    changeset =
      if finished_at do
        # Exhausted - set finished_at and clear scheduled_at
        changeset
        |> Ecto.Changeset.force_change(:finished_at, finished_at)
        |> Ecto.Changeset.force_change(:scheduled_at, nil)
      else
        # Retry - clear finished_at and set scheduled_at
        # Use put_change to explicitly set finished_at to nil
        # put_change will always include the field in changes, even if it's nil
        changeset
        |> Ecto.Changeset.put_change(:finished_at, nil)
        |> Ecto.Changeset.put_change(:performed_at, nil)
        |> Ecto.Changeset.put_change(:scheduled_at, scheduled_at)
      end

    changeset
  end

  defp update_job_cancel(job, reason, finished_at) do
    reason_string = format_error(reason)

    Job.changeset(job, %{
      finished_at: finished_at,
      error: reason_string,
      locked_by_id: nil,
      locked_at: nil
    })
  end

  defp update_job_discard(job, reason, finished_at) do
    reason_string = format_error(reason)

    Job.changeset(job, %{
      finished_at: finished_at,
      error: reason_string,
      locked_by_id: nil,
      locked_at: nil
    })
  end

  defp update_job_snooze(job, scheduled_at) do
    Job.changeset(job, %{
      scheduled_at: scheduled_at,
      locked_by_id: nil,
      locked_at: nil
    })
  end

  defp create_execution(job, error, finished_at, duration, process_id, stacktrace \\ []) do
    duration_interval = format_duration(duration)

    Execution.changeset(%Execution{}, %{
      active_job_id: job.active_job_id,
      job_class: job.job_class,
      queue_name: job.queue_name,
      serialized_params: job.serialized_params,
      scheduled_at: job.scheduled_at,
      finished_at: finished_at,
      error: if(error, do: format_error(error), else: nil),
      error_backtrace: if(error, do: format_backtrace(error, stacktrace), else: nil),
      process_id: normalize_process_id(process_id),
      duration: duration_interval
    })
  end

  defp normalize_process_id(nil), do: nil

  defp normalize_process_id(process_id) when is_binary(process_id) do
    case Ecto.UUID.cast(process_id) do
      {:ok, uuid} -> uuid
      :error -> nil
    end
  end

  defp normalize_process_id(_), do: nil

  defp format_error(error), do: Utils.format_error(error)

  defp format_backtrace(_error, stacktrace), do: Utils.format_backtrace(stacktrace)

  defp format_duration(duration_nanoseconds) do
    total_microseconds = div(duration_nanoseconds, 1_000)
    secs = div(total_microseconds, 1_000_000)
    microsecs = rem(total_microseconds, 1_000_000)
    %Postgrex.Interval{months: 0, days: 0, secs: secs, microsecs: microsecs}
  end
end
