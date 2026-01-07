defmodule GoodJob.JobExecutor.ResultHandlerTest do
  use GoodJob.Testing.JobCase

  alias GoodJob.{Job, Repo}
  alias GoodJob.JobExecutor.ResultHandler

  defmodule RetryJob do
    use GoodJob.Job, max_attempts: 2

    def perform(_args), do: :ok
  end

  setup do
    repo = Repo.repo()
    Ecto.Adapters.SQL.Sandbox.checkout(repo)
    Ecto.Adapters.SQL.Sandbox.mode(repo, {:shared, self()})
    :ok
  end

  test "normalize_result passes through known result shapes" do
    assert ResultHandler.normalize_result(:ok) == :ok
    assert ResultHandler.normalize_result({:ok, 1}) == {:ok, 1}
    assert ResultHandler.normalize_result({:error, "fail"}) == {:error, "fail"}
    assert ResultHandler.normalize_result({:cancel, "cancel"}) == {:cancel, "cancel"}
    assert ResultHandler.normalize_result(:discard) == :discard
    assert ResultHandler.normalize_result({:discard, "reason"}) == {:discard, "reason"}
    assert ResultHandler.normalize_result({:snooze, 10}) == {:snooze, 10}
    assert ResultHandler.normalize_result("other") == "other"
  end

  test "handle_success updates job and creates execution" do
    {:ok, job} = enqueue_job(RetryJob)

    start_time = System.monotonic_time()
    assert :ok == ResultHandler.handle_success(job, :ok, start_time, nil)

    updated = Repo.repo().get!(Job, job.id)
    assert updated.finished_at != nil
    assert updated.error == nil
    assert updated.executions_count == 1
  end

  test "handle_error retries when attempts remain" do
    {:ok, job} = enqueue_job(RetryJob)

    start_time = System.monotonic_time()
    assert :ok == ResultHandler.handle_error(job, "failed", start_time, nil)

    updated = Repo.repo().get!(Job, job.id)
    assert updated.finished_at == nil
    assert updated.scheduled_at != nil
    assert updated.executions_count == 1
    assert updated.serialized_params["executions"] == 1
  end

  test "handle_error exhausts when attempts are exceeded" do
    {:ok, job} = enqueue_job(RetryJob)
    Repo.repo().update!(Job.changeset(job, %{executions_count: 1}))

    start_time = System.monotonic_time()
    assert :ok == ResultHandler.handle_error(job, "failed", start_time, nil)

    updated = Repo.repo().get!(Job, job.id)
    assert updated.finished_at != nil
    assert updated.scheduled_at == nil
    assert updated.executions_count == 2
  end

  test "handle_cancel updates job and execution" do
    {:ok, job} = enqueue_job(RetryJob)
    start_time = System.monotonic_time()

    assert :ok == ResultHandler.handle_cancel(job, "cancelled", start_time, nil)
    updated = Repo.repo().get!(Job, job.id)
    assert updated.finished_at != nil
    assert updated.error =~ "cancelled"
  end

  test "handle_discard updates job and execution" do
    {:ok, job} = enqueue_job(RetryJob)
    start_time = System.monotonic_time()

    assert :ok == ResultHandler.handle_discard(job, "discarded", start_time, nil)
    updated = Repo.repo().get!(Job, job.id)
    assert updated.finished_at != nil
    assert updated.error =~ "discarded"
  end

  test "handle_snooze schedules job" do
    {:ok, job} = enqueue_job(RetryJob)
    start_time = System.monotonic_time()

    assert :ok == ResultHandler.handle_snooze(job, 60, start_time, nil)
    updated = Repo.repo().get!(Job, job.id)
    assert updated.scheduled_at != nil
  end

  defp enqueue_job(job_module) do
    active_job_id = Ecto.UUID.generate()
    external_job_class = GoodJob.Protocol.Serialization.module_to_external_class(job_module)

    serialized_params =
      GoodJob.Protocol.Serialization.to_active_job(
        job_class: external_job_class,
        arguments: [%{}],
        queue_name: "default",
        priority: 0,
        executions: 0,
        job_id: active_job_id
      )

    Job.enqueue(%{
      active_job_id: active_job_id,
      job_class: Atom.to_string(job_module),
      queue_name: "default",
      serialized_params: serialized_params,
      executions_count: 0
    })
  end
end
