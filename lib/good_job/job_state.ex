defmodule GoodJob.JobState do
  @moduledoc """
  Defines job states and state transitions.

  Job states:
  - `:available` - Job is ready to be executed
  - `:executing` - Job is currently being executed
  - `:completed` - Job completed successfully
  - `:discarded` - Job was discarded (failed after max attempts)
  - `:cancelled` - Job was cancelled
  - `:retryable` - Job failed but can be retried
  """

  @type t :: :available | :executing | :completed | :discarded | :cancelled | :retryable

  @all_states [:available, :executing, :completed, :discarded, :cancelled, :retryable]

  @doc """
  Returns all valid job states.
  """
  @spec all() :: [t()]
  def all, do: @all_states

  @doc """
  Checks if a state is valid.
  """
  @spec valid?(atom()) :: boolean()
  def valid?(state) when state in @all_states, do: true
  def valid?(_), do: false

  @doc """
  Transitions a job to a new state based on execution result.

  ## Examples

      iex> GoodJob.JobState.transition(:available, :ok)
      :completed

      iex> GoodJob.JobState.transition(:executing, {:error, "failed"})
      :retryable

      iex> GoodJob.JobState.transition(:executing, {:cancel, "cancelled"})
      :cancelled
  """
  @spec transition(t(), term()) :: t()
  def transition(_current, :ok), do: :completed
  def transition(_current, {:ok, _value}), do: :completed
  def transition(_current, {:cancel, _reason}), do: :cancelled
  def transition(_current, :discard), do: :discarded
  def transition(_current, {:discard, _reason}), do: :discarded
  def transition(_current, {:error, _reason}), do: :retryable
  def transition(_current, {:snooze, _seconds}), do: :available
  def transition(current, _result), do: current

  @doc """
  Checks if a job can transition from one state to another.
  """
  @spec can_transition?(t(), t()) :: boolean()
  def can_transition?(:available, :executing), do: true
  def can_transition?(:executing, :completed), do: true
  def can_transition?(:executing, :retryable), do: true
  def can_transition?(:executing, :cancelled), do: true
  def can_transition?(:executing, :discarded), do: true
  def can_transition?(:retryable, :available), do: true
  def can_transition?(:retryable, :discarded), do: true
  def can_transition?(_from, _to), do: false

  @doc """
  Checks if a state is a final state (cannot transition further).
  """
  @spec final?(t()) :: boolean()
  def final?(:completed), do: true
  def final?(:discarded), do: true
  def final?(:cancelled), do: true
  def final?(_), do: false

  @doc """
  Converts a state atom to a string for database storage.
  """
  @spec to_string(t()) :: String.t()
  def to_string(state) when state in @all_states, do: Atom.to_string(state)

  @doc """
  Converts a string to a state atom.
  """
  @spec from_string(String.t()) :: t() | nil
  def from_string(string) when is_binary(string) do
    case String.to_existing_atom(string) do
      atom when atom in @all_states -> atom
      _ -> nil
    end
  rescue
    ArgumentError -> nil
  end
end
