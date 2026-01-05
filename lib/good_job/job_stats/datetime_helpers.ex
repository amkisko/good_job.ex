defmodule GoodJob.JobStats.DatetimeHelpers do
  @moduledoc """
  Datetime conversion and formatting helpers for job statistics.
  """

  @doc """
  Converts various datetime formats to DateTime struct.
  """
  def convert_to_datetime(%NaiveDateTime{} = dt) do
    {:ok, DateTime.from_naive!(dt, "Etc/UTC")}
  end

  def convert_to_datetime(%DateTime{} = dt) do
    {:ok, dt}
  end

  def convert_to_datetime(%Date{} = date) do
    {:ok, DateTime.from_naive!(NaiveDateTime.new!(date, ~T[00:00:00]), "Etc/UTC")}
  end

  # REJECT all 2-tuples with integers FIRST - these are NOT timestamps
  # This must come before the date/time tuple pattern to catch {0, 6}, {487063, 6}, etc.
  def convert_to_datetime({a, b}) when is_integer(a) and is_integer(b) and tuple_size({a, b}) == 2 do
    # These are likely interval types or other PostgreSQL types, not timestamps
    :error
  end

  # Handle Erlang date/time tuple {{year, month, day}, {hour, min, sec}}
  # This pattern is more specific - requires nested tuples
  def convert_to_datetime({{y, m, d}, {h, min, s}})
      when is_integer(y) and is_integer(m) and is_integer(d) and
             is_integer(h) and is_integer(min) and
             tuple_size({y, m, d}) == 3 and tuple_size({h, min, s}) >= 2 do
    dt = NaiveDateTime.new!(y, m, d, h, min, s || 0)
    {:ok, DateTime.from_naive!(dt, "Etc/UTC")}
  rescue
    _ -> :error
  end

  def convert_to_datetime(other) when is_binary(other) do
    # Try to parse as ISO8601 string
    case DateTime.from_iso8601(other) do
      {:ok, dt, _} -> {:ok, dt}
      _ -> :error
    end
  end

  # Reject any other tuples or unknown types
  def convert_to_datetime(other) when is_tuple(other) do
    :error
  end

  def convert_to_datetime(_other) do
    :error
  end

  @doc """
  Formats a datetime for display (truncates to hour precision).
  """
  def format_hour(datetime) do
    datetime
    |> DateTime.to_naive()
    |> NaiveDateTime.to_string()
    |> String.slice(0, 16)
  end
end
