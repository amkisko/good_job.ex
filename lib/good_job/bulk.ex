defmodule GoodJob.Bulk do
  @moduledoc """
  Buffers and enqueues multiple jobs together.

  This mirrors the upstream GoodJob::Bulk API:
  - `capture/1` captures jobs enqueued within a block.
  - `enqueue/1` captures jobs and inserts them atomically in one transaction.
  - `enqueue/1` also accepts a list of `%GoodJob.Job.Instance{}`.
  """

  alias GoodJob.Job
  alias GoodJob.Job.Instance
  alias GoodJob.Repo

  @buffer_key {__MODULE__, :current_buffer}
  @insert_chunk_size 500

  @type entry :: %{
          required(:job_attrs) => map(),
          required(:callback_module) => module() | nil,
          required(:opts) => keyword()
        }

  @doc """
  Returns `true` when the current process is buffering jobs.
  """
  @spec buffering?() :: boolean()
  def buffering? do
    is_list(Process.get(@buffer_key))
  end

  @doc """
  Adds a job entry to the current buffer.

  This is used internally by `GoodJob.enqueue/3`.
  """
  @spec add(entry()) :: {:ok, :buffered} | {:error, :not_buffering}
  def add(entry) do
    case Process.get(@buffer_key) do
      buffer when is_list(buffer) ->
        Process.put(@buffer_key, [entry | buffer])
        {:ok, :buffered}

      _ ->
        {:error, :not_buffering}
    end
  end

  @doc """
  Captures jobs enqueued inside the given function.

  Returns captured job entries.
  """
  @spec capture((-> any())) :: [entry()]
  def capture(fun) when is_function(fun, 0) do
    {_result, entries} = with_buffer(fun)
    entries
  end

  @doc """
  Atomically enqueues jobs.

  Accepts either:
  - a function that enqueues jobs (`perform_later/1`, `GoodJob.enqueue/3`, etc.)
  - a list of `%GoodJob.Job.Instance{}`
  """
  @spec enqueue((-> any()) | [Instance.t()]) :: {:ok, [GoodJob.Job.t()]} | {:error, any()}
  def enqueue(fun) when is_function(fun, 0) do
    {_result, entries} = with_buffer(fun)
    flush(entries)
  end

  def enqueue(instances) when is_list(instances) do
    enqueue(fn ->
      Enum.each(instances, fn
        %Instance{job_module: job_module, args: args, options: options} ->
          _ = GoodJob.enqueue(job_module, args, options)

        invalid ->
          raise ArgumentError,
                "Expected %GoodJob.Job.Instance{}, got: #{inspect(invalid)}"
      end)
    end)
  end

  defp with_buffer(fun) do
    previous = Process.get(@buffer_key)
    Process.put(@buffer_key, [])

    try do
      result = fun.()
      entries = Process.get(@buffer_key, []) |> Enum.reverse()
      {result, entries}
    after
      restore_previous_buffer(previous)
    end
  end

  defp restore_previous_buffer(nil), do: Process.delete(@buffer_key)
  defp restore_previous_buffer(previous), do: Process.put(@buffer_key, previous)

  defp flush([]), do: {:ok, []}

  defp flush(entries) do
    repo = Repo.repo()
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    try do
      jobs =
        entries
        |> Enum.chunk_every(@insert_chunk_size)
        |> Enum.flat_map(fn chunk ->
          rows = Enum.map(chunk, &entry_to_insert_row(&1, now))
          {_count, returned} = repo.insert_all(Job, rows, returning: true)
          Enum.zip(chunk, returned)
        end)
        |> Enum.map(fn {entry, job} ->
          GoodJob.PubSub.broadcast(:job_created, job.id)
          GoodJob.Telemetry.enqueue(job)

          if is_atom(entry.callback_module) do
            GoodJob.JobCallbacks.after_enqueue(entry.callback_module, job, entry.opts)
          end

          job
        end)

      notify_after_bulk_flush(jobs)
      {:ok, jobs}
    rescue
      error ->
        {:error, error}
    end
  end

  defp entry_to_insert_row(%{job_attrs: attrs}, now) do
    attrs =
      attrs
      |> stringify_or_atom_map()
      |> align_id_with_active_job_id()

    id = Map.get(attrs, :id) || Map.get(attrs, "id") || Ecto.UUID.generate()
    active_job_id = Map.get(attrs, :active_job_id) || Map.get(attrs, "active_job_id") || id

    %{
      id: id,
      active_job_id: active_job_id,
      queue_name: Map.get(attrs, :queue_name) || Map.get(attrs, "queue_name"),
      priority: Map.get(attrs, :priority) || Map.get(attrs, "priority") || 0,
      serialized_params: Map.get(attrs, :serialized_params) || Map.get(attrs, "serialized_params"),
      scheduled_at: Map.get(attrs, :scheduled_at) || Map.get(attrs, "scheduled_at"),
      job_class: Map.get(attrs, :job_class) || Map.get(attrs, "job_class"),
      concurrency_key: Map.get(attrs, :concurrency_key) || Map.get(attrs, "concurrency_key"),
      cron_key: Map.get(attrs, :cron_key) || Map.get(attrs, "cron_key"),
      cron_at: Map.get(attrs, :cron_at) || Map.get(attrs, "cron_at"),
      batch_id: Map.get(attrs, :batch_id) || Map.get(attrs, "batch_id"),
      batch_callback_id: Map.get(attrs, :batch_callback_id) || Map.get(attrs, "batch_callback_id"),
      labels: Map.get(attrs, :labels) || Map.get(attrs, "labels"),
      is_discrete: Map.get(attrs, :is_discrete) || Map.get(attrs, "is_discrete"),
      executions_count: Map.get(attrs, :executions_count) || Map.get(attrs, "executions_count") || 0,
      inserted_at: now,
      updated_at: now
    }
  end

  defp stringify_or_atom_map(attrs) when is_map(attrs), do: attrs

  defp align_id_with_active_job_id(attrs) do
    active_job_id = Map.get(attrs, :active_job_id) || Map.get(attrs, "active_job_id")

    cond do
      is_nil(active_job_id) ->
        attrs

      Map.has_key?(attrs, :id) or Map.has_key?(attrs, "id") ->
        attrs

      true ->
        Map.put(attrs, :id, active_job_id)
    end
  end

  @doc false
  def notify_after_bulk_flush(jobs) when is_list(jobs), do: notify_after_bulk_flush_impl(jobs)

  defp notify_after_bulk_flush_impl(jobs) when is_list(jobs) do
    with true <- jobs != [],
         true <- GoodJob.Config.enable_listen_notify?() do
      now = DateTime.utc_now()

      job =
        Enum.find(jobs, fn j ->
          is_nil(j.scheduled_at) or DateTime.compare(j.scheduled_at, now) != :gt
        end)

      if job do
        job
        |> GoodJob.Protocol.Notification.for_job()
        |> GoodJob.Notifier.notify()
      end
    end
  end

  defp notify_after_bulk_flush_impl(_), do: :ok
end
