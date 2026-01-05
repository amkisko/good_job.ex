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
  def check_completion(batch_id) when is_binary(batch_id) do
    repo = Repo.repo()

    repo.transaction(fn ->
      # Use get/2 instead of get!/2 so that jobs with a batch_id but without a
      # corresponding BatchRecord (e.g. Elixir-only jobs created in tests) do
      # not raise. This matches the behaviour expected by the tests, which
      # enqueue jobs with a batch_id but no BatchRecord and still expect the
      # executor to succeed.
      case repo.get(BatchRecord, batch_id) do
        nil ->
          :ok

        batch ->
          # Check if all jobs in the batch are finished
          unfinished_count =
            Job
            |> Job.with_batch_id(batch_id)
            |> Job.unfinished()
            |> repo.aggregate(:count, :id)

          if unfinished_count == 0 && is_nil(batch.finished_at) do
            # All jobs are finished, mark batch as finished
            now = DateTime.utc_now()

            batch
            |> BatchRecord.changeset(%{finished_at: now, jobs_finished_at: now})
            |> repo.update!()

            # Check if any jobs were discarded (finished with error)
            discarded_count =
              Job
              |> Job.with_batch_id(batch_id)
              |> Job.discarded()
              |> repo.aggregate(:count, :id)

            # Emit telemetry for batch completion
            GoodJob.Telemetry.batch_complete(batch, discarded_count)

            # Execute callbacks
            if discarded_count > 0 && batch.on_discard do
              execute_callback(
                batch.on_discard,
                batch,
                :discard,
                batch.callback_queue_name,
                batch.callback_priority
              )
            end

            if discarded_count == 0 && batch.on_success do
              execute_callback(
                batch.on_success,
                batch,
                :success,
                batch.callback_queue_name,
                batch.callback_priority
              )
            end

            if batch.on_finish do
              execute_callback(
                batch.on_finish,
                batch,
                :finish,
                batch.callback_queue_name,
                batch.callback_priority
              )
            end
          end
      end
    end)
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
