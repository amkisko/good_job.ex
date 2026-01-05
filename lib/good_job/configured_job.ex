defmodule GoodJob.ConfiguredJob do
  @moduledoc """
  Represents a job with pre-configured options (similar to Rails ActiveJob's ConfiguredJob).

  This is returned by `MyJob.set(options)` and allows chaining with `perform_later/1` or `perform_now/1`.
  """

  defstruct [:job_module, :options]

  @doc """
  Creates a new configured job.
  """
  def new(job_module, options \\ []) do
    %__MODULE__{job_module: job_module, options: normalize_options(options)}
  end

  @doc """
  Executes the job immediately (perform_now).

  ## Examples

      MyJob.set(wait: 300).perform_now(%{data: "hello"})
  """
  def perform_now(%__MODULE__{job_module: job_module, options: options}, args \\ %{}) do
    # Merge options with execution_mode: :inline
    opts = Keyword.merge(options, execution_mode: :inline)
    GoodJob.enqueue(job_module, args, opts)
  end

  @doc """
  Enqueues the job for later execution (perform_later).

  ## Examples

      MyJob.set(wait: 300).perform_later(%{data: "hello"})
      MyJob.set(queue: "high").perform_later(%{data: "hello"})
  """
  def perform_later(%__MODULE__{job_module: job_module, options: options}, args \\ %{}) do
    GoodJob.enqueue(job_module, args, options)
  end

  defp normalize_options(options) when is_list(options) do
    options
    |> Enum.map(fn
      {:wait, seconds} when is_integer(seconds) ->
        scheduled_at = DateTime.add(DateTime.utc_now(), seconds, :second)
        {:scheduled_at, scheduled_at}

      {:wait_until, %DateTime{} = datetime} ->
        {:scheduled_at, datetime}

      {:wait_until, %NaiveDateTime{} = naive_datetime} ->
        scheduled_at = DateTime.from_naive!(naive_datetime, "Etc/UTC")
        {:scheduled_at, scheduled_at}

      other ->
        other
    end)
  end

  defp normalize_options(_options), do: []
end
