defmodule GoodJob.Utils do
  @moduledoc """
  Shared utility functions used across GoodJob modules.
  """

  @doc """
  Formats an error for display in logs and error messages.

  Handles strings, exceptions, and other types.
  """
  def format_error(error) when is_binary(error), do: error
  def format_error(error) when is_exception(error), do: Exception.message(error)
  def format_error(error), do: inspect(error)

  @doc """
  Formats a datetime for display in logs.

  Returns "nil" for nil values, otherwise formats as "YYYY-MM-DD HH:MM:SS".
  """
  def format_datetime_log(nil), do: "nil"
  def format_datetime_log(datetime), do: Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S")

  @doc """
  Formats a duration in microseconds to a human-readable string.

  Examples:
  - 1000 -> "1ms"
  - 1000000 -> "1s"
  - 1500000 -> "1.5s"
  """
  def format_duration_microseconds(duration) when is_integer(duration) do
    cond do
      duration < 1000 ->
        "#{duration}μs"

      duration < 1_000_000 ->
        "#{div(duration, 1000)}ms"

      true ->
        seconds = div(duration, 1_000_000)
        remainder_ms = rem(duration, 1_000_000) |> div(1000)

        if remainder_ms > 0 do
          "#{seconds}.#{remainder_ms}s"
        else
          "#{seconds}s"
        end
    end
  end

  def format_duration_microseconds(_), do: "unknown"

  @doc """
  Formats a backtrace for display.

  Uses Exception.format_stacktrace when available, otherwise formats manually.
  Returns a list of strings (one per line).
  """
  def format_backtrace(stacktrace) when is_list(stacktrace) do
    if function_exported?(Exception, :format_stacktrace, 1) and stacktrace != [] do
      Exception.format_stacktrace(stacktrace)
      |> String.split("\n")
    else
      []
    end
  end

  def format_backtrace(_), do: []
end
