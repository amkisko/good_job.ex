defmodule GoodJob.JobRecovery do
  @moduledoc false

  import Ecto.Query

  alias GoodJob.{Execution, Job, Repo}

  @doc """
  Releases a job after the worker task died (e.g. `:DOWN` from `Task.Supervisor`).

  Clears lock state so the job can be picked up again, and closes open execution rows.
  """
  @spec after_worker_crash(Job.t(), term()) :: :ok
  def after_worker_crash(%Job{} = job, reason) do
    now = DateTime.utc_now()
    error = "Worker crashed: #{inspect(reason)}"
    duration = %Postgrex.Interval{months: 0, days: 0, secs: 0, microsecs: 0}
    repo = Repo.repo()

    repo.transaction(fn ->
      _ =
        repo.update_all(
          from(e in Execution,
            where: e.active_job_id == ^job.active_job_id,
            where: is_nil(e.finished_at)
          ),
          set: [error: error, finished_at: now, error_event: 0, duration: duration]
        )

      _ =
        repo.update_all(
          from(j in Job, where: j.id == ^job.id),
          set: [locked_by_id: nil, locked_at: nil, performed_at: nil]
        )

      :ok
    end)

    :ok
  end
end
