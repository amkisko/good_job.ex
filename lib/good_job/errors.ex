defmodule GoodJob.Errors do
  @moduledoc """
  Error handling utilities for GoodJob.

  Provides error classification, retry logic, and error reporting for production use.
  """

  defmodule ConcurrencyExceededError do
    defexception [:message, :concurrency_key]
  end

  defmodule ThrottleExceededError do
    defexception [:message, :concurrency_key]
  end

  defmodule ConfigurationError do
    defexception [:message]
  end

  defmodule JobTimeoutError do
    defexception [:message, :job_id, :timeout_ms]
  end

  @doc """
  Classifies an error to determine if it should be retried.

  Returns:
  - `:retry` - Error is temporary and should be retried
  - `:discard` - Error is permanent and job should be discarded
  """
  @spec classify_error(term()) :: :retry | :discard
  def classify_error(%DBConnection.ConnectionError{}), do: :retry
  def classify_error(%DBConnection.TransactionError{}), do: :retry

  def classify_error(%Postgrex.Error{postgres: %{code: code}})
      when code in [
             :connection_exception,
             :query_canceled,
             :deadlock_detected,
             :serialization_failure,
             :statement_timeout,
             :lock_timeout
           ],
      do: :retry

  def classify_error(%Ecto.Query.CastError{}), do: :discard
  def classify_error(%Ecto.Changeset{}), do: :discard
  def classify_error(%ArgumentError{}), do: :discard
  def classify_error(%FunctionClauseError{}), do: :discard
  def classify_error(_), do: :retry

  @doc """
  Formats an error for logging and reporting.

  Returns a map with error details suitable for logging and telemetry.
  """
  @spec format_error(term()) :: map()
  def format_error(error) when is_exception(error) do
    %{
      class: error.__struct__ |> Module.split() |> List.last(),
      message: Exception.message(error),
      stacktrace: nil
    }
  end

  def format_error(error) when is_binary(error) do
    %{
      class: "String",
      message: error,
      stacktrace: nil
    }
  end

  def format_error(error) do
    %{
      class: "Unknown",
      message: inspect(error),
      stacktrace: nil
    }
  end

  @doc """
  Checks if an error is a database connection error.

  These errors are typically temporary and should be retried.
  """
  @spec connection_error?(term()) :: boolean()
  def connection_error?(%DBConnection.ConnectionError{}), do: true
  def connection_error?(%DBConnection.TransactionError{}), do: true

  def connection_error?(%Postgrex.Error{postgres: %{code: code}}) when code in [:connection_exception, :query_canceled],
    do: true

  def connection_error?(_), do: false

  @doc """
  Checks if an error is a timeout error.

  These errors may indicate overload and should be retried with backoff.
  """
  @spec timeout_error?(term()) :: boolean()
  def timeout_error?(%Postgrex.Error{postgres: %{code: code}}) when code in [:statement_timeout, :lock_timeout],
    do: true

  def timeout_error?(%JobTimeoutError{}), do: true

  def timeout_error?(error) when is_exception(error) do
    message = Exception.message(error) |> String.downcase()
    String.contains?(message, "timeout") or String.contains?(message, "timed out")
  end

  def timeout_error?(_), do: false

  @doc """
  Checks if an error is a permanent error that should not be retried.

  These errors indicate programming errors or invalid data.
  """
  @spec permanent_error?(term()) :: boolean()
  def permanent_error?(%Ecto.Query.CastError{}), do: true
  def permanent_error?(%Ecto.Changeset{}), do: true
  def permanent_error?(%ArgumentError{}), do: true
  def permanent_error?(%FunctionClauseError{}), do: true
  def permanent_error?(_), do: false
end
