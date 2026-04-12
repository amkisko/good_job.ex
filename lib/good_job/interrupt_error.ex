defmodule GoodJob.InterruptError do
  @moduledoc """
  Exception raised when a job is interrupted (e.g., during shutdown).

  Jobs that raise this error should not be retried.

  `GoodJob.Errors.classify_error/1` and `GoodJob.Errors.permanent_error?/1` treat this
  exception as non-retryable (discard / permanent).
  """

  defexception message: "Job was interrupted"

  @type t :: %__MODULE__{
          message: String.t()
        }
end
