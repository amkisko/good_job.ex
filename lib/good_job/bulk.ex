defmodule GoodJob.Bulk do
  @moduledoc """
  Buffers and enqueues multiple jobs together.

  This mirrors the Ruby GoodJob::Bulk API:
  - `capture/1` captures jobs enqueued within a block.
  - `enqueue/1` captures jobs and inserts them atomically in one transaction.
  - `enqueue/1` also accepts a list of `%GoodJob.Job.Instance{}`.
  """

  alias GoodJob.Job.Instance
  alias GoodJob.Repo

  @buffer_key {__MODULE__, :current_buffer}

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

    repo.transaction(fn ->
      Enum.reduce_while(entries, [], fn entry, acc ->
        case GoodJob.Job.enqueue(entry.job_attrs) do
          {:ok, job} ->
            if is_atom(entry.callback_module) do
              GoodJob.JobCallbacks.after_enqueue(entry.callback_module, job, entry.opts)
            end

            {:cont, [job | acc]}

          {:error, reason} ->
            repo.rollback(reason)
        end
      end)
      |> Enum.reverse()
    end)
    |> case do
      {:ok, jobs} -> {:ok, jobs}
      {:error, reason} -> {:error, reason}
    end
  end
end
