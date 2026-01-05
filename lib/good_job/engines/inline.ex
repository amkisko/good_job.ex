defmodule GoodJob.Engines.Inline do
  @moduledoc """
  Inline engine for testing.

  Executes jobs immediately in the current process without database persistence.
  """

  alias GoodJob.{Config, Executor, Job}

  @doc """
  Inserts and immediately executes a job.
  """
  @spec insert_job(Config.t(), Ecto.Changeset.t(), keyword()) :: {:ok, Job.t()} | {:error, term()}
  def insert_job(_config, changeset, _opts) do
    case GoodJob.Repo.repo().insert(changeset) do
      {:ok, job} ->
        exec = Executor.new(job, safe: false)
        exec = Executor.call(exec)
        updated_job = update_job_from_execution(job, exec)
        {:ok, updated_job}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  defp update_job_from_execution(job, exec) do
    repo = GoodJob.Repo.repo()
    now = DateTime.utc_now()
    fresh_job = repo.get!(Job, job.id)
    job_id = fresh_job.id

    {update_attrs, executions_count} =
      case exec.state do
        :success ->
          {%{finished_at: now, performed_at: now, error: nil}, nil}

        :failure ->
          error_message = format_error(exec.error)
          {%{finished_at: now, performed_at: now, error: error_message}, (fresh_job.executions_count || 0) + 1}

        :exhausted ->
          error_message =
            case format_error(exec.error) do
              nil -> "Job exhausted after max attempts"
              msg -> msg
            end

          {%{finished_at: now, performed_at: now, error: error_message}, (fresh_job.executions_count || 0) + 1}

        :cancelled ->
          {%{finished_at: now, performed_at: now, error: "Job cancelled"}, nil}

        :discard ->
          {%{finished_at: now, performed_at: now, error: "Job discarded"}, nil}

        :snoozed ->
          {%{scheduled_at: now}, nil}

        :unset ->
          {%{}, nil}

        _other ->
          {%{}, nil}
      end

    if update_attrs != %{} or exec.state in [:success, :failure, :exhausted, :cancelled, :discard] do
      final_attrs =
        if executions_count do
          Map.merge(update_attrs, %{executions_count: executions_count})
        else
          update_attrs
        end

      import Ecto.Query

      set_clause = [
        finished_at: Map.get(final_attrs, :finished_at),
        performed_at: Map.get(final_attrs, :performed_at),
        error: Map.get(final_attrs, :error)
      ]

      set_clause =
        if executions_count do
          Keyword.put(set_clause, :executions_count, executions_count)
        else
          set_clause
        end

      repo.update_all(
        from(j in Job, where: j.id == ^job_id),
        set: set_clause
      )

      repo.get!(Job, job_id)
    else
      fresh_job
    end
  end

  defp format_error(nil), do: nil
  defp format_error(error) when is_exception(error), do: Exception.message(error)
  defp format_error(error), do: inspect(error)
end
