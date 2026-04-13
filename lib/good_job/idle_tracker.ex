defmodule GoodJob.IdleTracker do
  @moduledoc false

  @key {__MODULE__, :last_execution_at}

  @doc """
  Records worker activity (job dispatched to a task). Resets idle shutdown timer.
  """
  def touch_execution do
    :persistent_term.put(@key, System.monotonic_time(:second))
  end

  @doc """
  Monotonic second timestamp of last job dispatch, or startup time from `init_started/0`.
  """
  def last_execution_at do
    :persistent_term.get(@key, nil)
  end

  @doc """
  Call when GoodJob starts so idle timeout is measured from process start when no jobs run.
  """
  def init_started do
    touch_execution()
  end
end
