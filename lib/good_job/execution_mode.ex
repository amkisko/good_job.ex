defmodule GoodJob.ExecutionMode do
  @moduledoc """
  Handles different execution modes for jobs.

  Execution modes:
  - `:inline` - Execute immediately in the current process
  - `:async` - Execute in background (default)
  - `:external` - Execute in a separate process
  """

  @type t :: :inline | :async | :external

  @doc """
  Executes a job based on the execution mode.
  """
  @spec execute(GoodJob.Job.t(), t(), keyword()) :: term()
  def execute(job, mode, opts \\ [])

  def execute(job, :inline, opts) do
    GoodJob.JobExecutor.execute_inline(job, opts)
  end

  def execute(job, :async, _opts) do
    # Default mode - enqueue for background processing
    {:ok, job}
  end

  def execute(job, :external, _opts) do
    # Execute in separate process
    Task.start(fn ->
      GoodJob.JobExecutor.execute(job, nil)
    end)

    {:ok, job}
  end

  def execute(_job, mode, _opts) do
    raise ArgumentError, "Invalid execution mode: #{inspect(mode)}"
  end
end
