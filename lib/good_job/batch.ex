defmodule GoodJob.Batch do
  @moduledoc """
  Batch job management.

  Batches allow you to group jobs together and execute callbacks when all jobs complete.
  """

  alias GoodJob.{Batch, BatchRecord, Job, Repo}

  @doc """
  Creates a new batch and enqueues jobs within it.

  ## Examples

      batch = GoodJob.Batch.new()
      |> GoodJob.Batch.add_job(MyApp.Job1, %{data: "1"})
      |> GoodJob.Batch.add_job(MyApp.Job2, %{data: "2"})
      |> GoodJob.Batch.enqueue()

      # With callbacks
      batch = GoodJob.Batch.new(
        on_finish: MyApp.BatchCallback,
        on_success: MyApp.BatchCallback,
        on_discard: MyApp.BatchCallback
      )
      |> GoodJob.Batch.add_job(MyApp.Job1, %{data: "1"})
      |> GoodJob.Batch.enqueue()
  """
  defstruct [
    :description,
    :on_finish,
    :on_success,
    :on_discard,
    :callback_queue_name,
    :callback_priority,
    :jobs
  ]

  def new(opts \\ []) do
    %__MODULE__{
      description: Keyword.get(opts, :description),
      on_finish: Keyword.get(opts, :on_finish),
      on_success: Keyword.get(opts, :on_success),
      on_discard: Keyword.get(opts, :on_discard),
      callback_queue_name: Keyword.get(opts, :callback_queue, "default"),
      callback_priority: Keyword.get(opts, :callback_priority, 0),
      jobs: []
    }
  end

  @doc """
  Adds a job to the batch.
  """
  def add_job(%Batch{} = batch, job_module, args, opts \\ []) do
    job = %{
      module: job_module,
      args: args,
      opts: opts
    }

    %{batch | jobs: [job | batch.jobs]}
  end

  @doc """
  Enqueues all jobs in the batch.
  """
  def enqueue(%Batch{} = batch) do
    _repo = Repo.repo()

    # Create batch record
    batch_record = create_batch_record(batch)

    # Enqueue all jobs with batch_id
    Enum.each(batch.jobs, fn job ->
      GoodJob.enqueue(job.module, job.args, Keyword.merge(job.opts, batch_id: batch_record.id))
    end)

    GoodJob.Telemetry.batch_enqueue(batch_record, length(batch.jobs))

    {:ok, batch_record}
  end

  defp create_batch_record(batch) do
    repo = Repo.repo()

    attrs = %{
      description: batch.description,
      serialized_properties: %{},
      on_finish: serialize_callback(batch.on_finish),
      on_success: serialize_callback(batch.on_success),
      on_discard: serialize_callback(batch.on_discard),
      callback_queue_name: batch.callback_queue_name,
      callback_priority: batch.callback_priority,
      enqueued_at: DateTime.utc_now()
    }

    %BatchRecord{}
    |> BatchRecord.changeset(attrs)
    |> repo.insert!()
  end

  @doc """
  Checks if a batch is complete and executes callbacks if needed.
  """
  def check_completion(batch_id, job \\ nil) when is_binary(batch_id) do
    repo = Repo.repo()

    repo.transaction(fn ->
      case repo.get(BatchRecord, batch_id) do
        nil ->
          :ok

        fresh_batch ->
          job_discarded = job && not is_nil(job.finished_at) && not is_nil(job.error)

          fresh_batch =
            if job_discarded && is_nil(fresh_batch.discarded_at) do
              updated_batch =
                fresh_batch
                |> BatchRecord.changeset(%{discarded_at: DateTime.utc_now()})
                |> repo.update!()

              if updated_batch.on_discard do
                execute_callback(
                  updated_batch.on_discard,
                  updated_batch,
                  :discard,
                  updated_batch.callback_queue_name,
                  updated_batch.callback_priority
                )
              end

              updated_batch
            else
              fresh_batch
            end

          fresh_batch =
            if not is_nil(fresh_batch.enqueued_at) &&
                 is_nil(fresh_batch.jobs_finished_at) &&
                 unfinished_jobs_count(repo, batch_id) == 0 do
              now = DateTime.utc_now()

              updated_batch =
                fresh_batch
                |> BatchRecord.changeset(%{jobs_finished_at: now})
                |> repo.update!()

              discarded_count = discarded_jobs_count(repo, batch_id)

              GoodJob.Telemetry.batch_complete(updated_batch, discarded_count)

              if discarded_count == 0 && updated_batch.on_success do
                execute_callback(
                  updated_batch.on_success,
                  updated_batch,
                  :success,
                  updated_batch.callback_queue_name,
                  updated_batch.callback_priority
                )
              end

              if updated_batch.on_finish do
                execute_callback(
                  updated_batch.on_finish,
                  updated_batch,
                  :finish,
                  updated_batch.callback_queue_name,
                  updated_batch.callback_priority
                )
              end

              updated_batch
            else
              fresh_batch
            end

          if is_nil(fresh_batch.finished_at) &&
               jobs_finished?(fresh_batch) &&
               unfinished_callback_jobs_count(repo, batch_id) == 0 do
            fresh_batch
            |> BatchRecord.changeset(%{finished_at: DateTime.utc_now()})
            |> repo.update!()
          end
      end
    end)
  end

  defp unfinished_jobs_count(repo, batch_id) do
    Job
    |> Job.with_batch_id(batch_id)
    |> Job.unfinished()
    |> repo.aggregate(:count, :id)
  end

  defp discarded_jobs_count(repo, batch_id) do
    Job
    |> Job.with_batch_id(batch_id)
    |> Job.discarded()
    |> repo.aggregate(:count, :id)
  end

  defp unfinished_callback_jobs_count(repo, batch_id) do
    import Ecto.Query

    from(j in Job, where: j.batch_callback_id == ^batch_id, where: is_nil(j.finished_at))
    |> repo.aggregate(:count, :id)
  end

  defp jobs_finished?(batch) do
    not is_nil(batch.jobs_finished_at) || not is_nil(batch.finished_at)
  end

  defp execute_callback(callback_string, batch, event, queue, priority) when is_binary(callback_string) do
    case Code.ensure_loaded(String.to_existing_atom(callback_string)) do
      {:module, callback_module} ->
        if function_exported?(callback_module, :perform, 1) do
          # Enqueue callback job
          GoodJob.enqueue(callback_module, %{batch: batch, event: event},
            queue: queue,
            priority: priority,
            batch_callback_id: batch.id
          )

          GoodJob.Telemetry.batch_callback(batch, event, callback_string)
        end

      _ ->
        :ok
    end
  end

  defp execute_callback(_, _, _, _, _), do: :ok

  @doc """
  Retries all discarded jobs in a batch.
  """
  def retry_batch(%BatchRecord{} = batch) do
    repo = Repo.repo()

    discarded_jobs =
      Job
      |> Job.with_batch_id(batch.id)
      |> Job.discarded()
      |> repo.all()

    # Retry each discarded job
    Enum.each(discarded_jobs, fn job ->
      Job.retry(job)
    end)

    # Clear discarded_at if batch was discarded
    if batch.discarded_at do
      batch
      |> BatchRecord.changeset(%{discarded_at: nil})
      |> repo.update()
    end

    GoodJob.Telemetry.batch_retry(batch)

    :ok
  end

  defp serialize_callback(nil), do: nil
  defp serialize_callback(module) when is_atom(module), do: to_string(module)
  defp serialize_callback(string) when is_binary(string), do: string
end
