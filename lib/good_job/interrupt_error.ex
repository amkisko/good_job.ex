defmodule GoodJob.InterruptError do
  @moduledoc """
  Exception raised when a job is interrupted (e.g., during shutdown).

  Jobs that raise this error should not be retried.
  """

  defexception message: "Job was interrupted"

  @type t :: %__MODULE__{
          message: String.t()
        }
end
