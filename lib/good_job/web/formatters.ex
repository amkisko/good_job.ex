defmodule GoodJob.Web.Formatters do
  @moduledoc """
  Formatting utilities for GoodJob LiveDashboard.
  """

  def format_datetime(nil), do: "-"

  def format_datetime(datetime) do
    datetime
    |> DateTime.to_naive()
    |> NaiveDateTime.to_string()
  end

  def format_duration(nil), do: "-"

  def format_duration(%Postgrex.Interval{} = interval) do
    parts = []
    parts = if interval.months > 0, do: ["#{interval.months}mo" | parts], else: parts
    parts = if interval.days > 0, do: ["#{interval.days}d" | parts], else: parts

    # Postgrex.Interval uses secs and microsecs, not microseconds
    total_seconds = interval.secs + div(interval.microsecs, 1_000_000)
    parts = if total_seconds > 0, do: ["#{total_seconds}s" | parts], else: parts

    if Enum.empty?(parts), do: "0s", else: Enum.join(parts, " ")
  end

  def format_duration(_), do: "-"

  def format_count(count) when count < 1000, do: to_string(count)
  def format_count(count) when count < 1_000_000, do: "#{div(count, 1000)}K"
  def format_count(count), do: "#{div(count, 1_000_000)}M"

  def format_job_class(class) when is_atom(class), do: inspect(class)
  def format_job_class(class) when is_binary(class), do: class
  def format_job_class(_), do: "N/A"

  def state_badge_class(:queued), do: "info"
  def state_badge_class(:running), do: "primary"
  def state_badge_class(:succeeded), do: "success"
  def state_badge_class(:discarded), do: "danger"
  def state_badge_class(:scheduled), do: "secondary"
  def state_badge_class(_), do: "secondary"
end
