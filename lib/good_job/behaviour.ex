defmodule GoodJob.Behaviour do
  @moduledoc """
  Behaviour for GoodJob workers.

  Jobs should implement this behaviour to define their execution logic.
  """

  @doc """
  Performs the job with the given arguments.

  Returns:
  - `:ok` or `{:ok, value}` - Job succeeded
  - `{:error, reason}` - Job failed and should be retried (if retries available)
  - `{:cancel, reason}` - Job should be cancelled and not retried
  - `:discard` or `{:discard, reason}` - Job should be discarded (not retried)
  - `{:snooze, seconds}` - Job should be rescheduled for later execution
  """
  @callback perform(args :: map()) ::
              :ok
              | {:ok, any()}
              | {:error, any()}
              | {:cancel, any()}
              | :discard
              | {:discard, any()}
              | {:snooze, integer()}

  @doc """
  Optional callback to customize retry backoff.

  Returns the number of seconds to wait before retrying.
  """
  @callback backoff(attempt :: integer()) :: integer()

  @doc """
  Optional callback to get maximum retry attempts.

  Returns the maximum number of attempts before giving up.
  """
  @callback max_attempts() :: integer()

  @optional_callbacks [backoff: 1, max_attempts: 0]
end
