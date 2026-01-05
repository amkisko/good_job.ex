defmodule GoodJob.CleanupTracker do
  @moduledoc """
  Tracks cleanup intervals for automatic job cleanup.

  Monitors both time-based and count-based cleanup intervals and triggers
  cleanup when thresholds are exceeded.
  """

  defstruct cleanup_interval_seconds: false,
            cleanup_interval_jobs: false,
            job_count: 0,
            last_at: nil

  @doc """
  Creates a new cleanup tracker.

  ## Options

    * `:cleanup_interval_seconds` - Number of seconds between cleanups (default: `false` to disable)
    * `:cleanup_interval_jobs` - Number of jobs executed between cleanups (default: `false` to disable)

  ## Examples

      tracker = CleanupTracker.new(cleanup_interval_seconds: 600, cleanup_interval_jobs: 1000)
      tracker = CleanupTracker.new(cleanup_interval_seconds: false) # Disable time-based cleanup
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    cleanup_interval_seconds = Keyword.get(opts, :cleanup_interval_seconds, false)
    cleanup_interval_jobs = Keyword.get(opts, :cleanup_interval_jobs, false)

    # Validate: 0 is not allowed, use false to disable
    if cleanup_interval_seconds == 0 or cleanup_interval_jobs == 0 do
      raise ArgumentError,
            "Do not use `0` for cleanup intervals. Use `false` to disable, or `-1` to always run"
    end

    %__MODULE__{
      cleanup_interval_seconds: cleanup_interval_seconds,
      cleanup_interval_jobs: cleanup_interval_jobs,
      job_count: 0,
      last_at: DateTime.utc_now()
    }
  end

  @doc """
  Increments the job count.
  """
  @spec increment(t()) :: t()
  def increment(%__MODULE__{} = tracker) do
    %{tracker | job_count: tracker.job_count + 1}
  end

  @doc """
  Checks if cleanup should be run.

  Returns `true` if either threshold is exceeded, `false` otherwise.
  """
  @spec cleanup?(t()) :: boolean()
  def cleanup?(%__MODULE__{} = tracker) do
    cond do
      # Always run if interval is -1
      tracker.cleanup_interval_jobs == -1 ->
        true

      # Check job count threshold
      tracker.cleanup_interval_jobs && tracker.job_count >= tracker.cleanup_interval_jobs ->
        true

      # Always run if interval is -1
      tracker.cleanup_interval_seconds == -1 ->
        true

      # Check time threshold
      tracker.cleanup_interval_seconds && tracker.last_at ->
        seconds_since_last = DateTime.diff(DateTime.utc_now(), tracker.last_at, :second)
        seconds_since_last >= tracker.cleanup_interval_seconds

      true ->
        false
    end
  end

  @doc """
  Resets the tracker counters.
  """
  @spec reset(t()) :: t()
  def reset(%__MODULE__{} = tracker) do
    %{
      tracker
      | job_count: 0,
        last_at: DateTime.utc_now()
    }
  end

  @type t :: %__MODULE__{
          cleanup_interval_seconds: integer() | false,
          cleanup_interval_jobs: integer() | false,
          job_count: integer(),
          last_at: DateTime.t() | nil
        }
end
