defmodule GoodJob.Types.Interval do
  @moduledoc """
  Custom Ecto type for PostgreSQL interval.

  Handles conversion between Postgrex.Interval struct and duration values.
  """

  @behaviour Ecto.Type

  def type, do: :interval

  def cast(%Postgrex.Interval{} = interval), do: {:ok, interval}

  def cast(seconds) when is_number(seconds) do
    # Convert seconds to secs and microsecs for Postgrex.Interval
    total_microseconds = trunc(seconds * 1_000_000)
    secs = div(total_microseconds, 1_000_000)
    microsecs = rem(total_microseconds, 1_000_000)
    {:ok, %Postgrex.Interval{months: 0, days: 0, secs: secs, microsecs: microsecs}}
  end

  def cast(string) when is_binary(string) do
    # Parse string like "0.11753 seconds" or "5 seconds"
    case parse_interval_string(string) do
      {:ok, interval} -> {:ok, interval}
      :error -> :error
    end
  end

  def cast(_), do: :error

  def load(%Postgrex.Interval{} = interval), do: {:ok, interval}
  def load(_), do: :error

  def dump(%Postgrex.Interval{} = interval), do: {:ok, interval}
  def dump(_), do: :error

  def equal?(%Postgrex.Interval{} = a, %Postgrex.Interval{} = b) do
    a.months == b.months and a.days == b.days and a.secs == b.secs and a.microsecs == b.microsecs
  end

  def equal?(_, _), do: false

  def embed_as(_), do: :self

  # Parse interval string like "0.11753 seconds" or "5 seconds"
  defp parse_interval_string(string) do
    case Regex.run(~r/^([\d.]+)\s*(?:seconds?|secs?)?$/i, String.trim(string)) do
      [_, seconds_str] ->
        case Float.parse(seconds_str) do
          {seconds, _} ->
            total_microseconds = trunc(seconds * 1_000_000)
            secs = div(total_microseconds, 1_000_000)
            microsecs = rem(total_microseconds, 1_000_000)
            {:ok, %Postgrex.Interval{months: 0, days: 0, secs: secs, microsecs: microsecs}}

          :error ->
            :error
        end

      _ ->
        :error
    end
  end
end
