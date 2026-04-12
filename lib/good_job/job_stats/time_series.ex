defmodule GoodJob.JobStats.TimeSeries do
  @moduledoc """
  Time series functions for job activity over time.
  """

  alias Ecto.Adapters.SQL
  alias GoodJob.{JobStats.DatetimeHelpers, Repo}

  @doc """
  Returns raw job activity data over time.
  Groups jobs by hour for the last N hours showing created, completed, and failed counts.

  Returns a map with `:labels`, `:created`, `:completed`, and `:failed` keys.
  UI concerns (colors, chart labels, etc.) should be handled by view/controller layers
  using `GoodJob.Web.ChartFormatter.format_activity_chart/1`.
  """
  @spec activity_over_time(integer()) :: %{
          labels: [String.t()],
          created: [integer()],
          completed: [integer()],
          failed: [integer()]
        }
  def activity_over_time(hours \\ 24) do
    repo = Repo.repo()
    end_time = DateTime.utc_now()
    start_time = DateTime.add(end_time, -hours, :hour)

    # Use raw SQL queries to avoid Ecto type casting issues
    # This ensures we get proper timestamps that can be converted to DateTime

    created_sql = """
    SELECT
      date_trunc('hour', created_at)::timestamptz AS hour,
      COUNT(*) AS count
    FROM good_jobs
    WHERE created_at >= $1 AND created_at <= $2
    GROUP BY date_trunc('hour', created_at)
    ORDER BY hour ASC
    """

    created_data = query_hourly_data(repo, created_sql, [start_time, end_time])

    completed_sql = """
    SELECT
      date_trunc('hour', finished_at)::timestamptz AS hour,
      COUNT(*) AS count
    FROM good_jobs
    WHERE finished_at >= $1 AND finished_at <= $2
      AND error IS NULL
    GROUP BY date_trunc('hour', finished_at)
    ORDER BY hour ASC
    """

    completed_data = query_hourly_data(repo, completed_sql, [start_time, end_time])

    failed_sql = """
    SELECT
      date_trunc('hour', finished_at)::timestamptz AS hour,
      COUNT(*) AS count
    FROM good_jobs
    WHERE finished_at >= $1 AND finished_at <= $2
      AND error IS NOT NULL
    GROUP BY date_trunc('hour', finished_at)
    ORDER BY hour ASC
    """

    failed_data = query_hourly_data(repo, failed_sql, [start_time, end_time])

    # Generate all hours in the range (truncated to hour)
    all_hours = generate_hour_range(hours)

    # Build data arrays for each hour
    # Normalize DateTime keys for lookup to ensure exact matches
    labels = Enum.map(all_hours, &DatetimeHelpers.format_hour/1)

    created = Enum.map(all_hours, &hour_bucket_count(created_data, &1))
    completed = Enum.map(all_hours, &hour_bucket_count(completed_data, &1))
    failed = Enum.map(all_hours, &hour_bucket_count(failed_data, &1))

    %{
      labels: labels,
      created: created,
      completed: completed,
      failed: failed
    }
  end

  # Private helpers

  defp generate_hour_range(hours) do
    try do
      now = DateTime.utc_now()
      now_naive = DateTime.to_naive(now)
      truncated_now = %{now_naive | minute: 0, second: 0, microsecond: {0, 0}}
      start_naive = NaiveDateTime.add(truncated_now, -hours * 3600, :second)
      start_naive_truncated = %{start_naive | minute: 0, second: 0, microsecond: {0, 0}}

      # Convert to DateTime and validate
      start_hour = DateTime.from_naive!(start_naive_truncated, "Etc/UTC")
      end_hour = DateTime.from_naive!(truncated_now, "Etc/UTC")

      # Generate hour list with validation
      Stream.unfold(start_hour, fn
        nil ->
          nil

        current when is_struct(current, DateTime) ->
          if DateTime.compare(current, end_hour) == :gt do
            nil
          else
            # Ensure DateTime.add returns a valid DateTime
            next =
              try do
                DateTime.add(current, 1, :hour)
              rescue
                _ -> nil
              end

            if is_struct(next, DateTime) do
              {current, next}
            else
              nil
            end
          end

        _ ->
          # If current is not a DateTime, stop the stream
          nil
      end)
      |> Enum.to_list()
    rescue
      _ ->
        try do
          now = DateTime.utc_now()

          if is_struct(now, DateTime) do
            [%{now | minute: 0, second: 0, microsecond: {0, 0}}]
          else
            now_naive = NaiveDateTime.utc_now()
            truncated = %{now_naive | minute: 0, second: 0, microsecond: {0, 0}}
            [DateTime.from_naive!(truncated, "Etc/UTC")]
          end
        rescue
          _ ->
            # Absolute fallback: return empty list
            []
        end
    end
    |> then(fn hours ->
      # Ensure we have at least some hours to display
      if Enum.empty?(hours) do
        # Fallback: create a simple hour list
        try do
          now = DateTime.utc_now()

          if is_struct(now, DateTime) do
            [%{now | minute: 0, second: 0, microsecond: {0, 0}}]
          else
            now_naive = NaiveDateTime.utc_now()
            truncated = %{now_naive | minute: 0, second: 0, microsecond: {0, 0}}
            [DateTime.from_naive!(truncated, "Etc/UTC")]
          end
        rescue
          _ ->
            []
        end
      else
        hours
      end
    end)
  end

  defp hour_bucket_count(data_map, hour) when is_struct(hour, DateTime) do
    case truncate_utc_hour(hour) do
      nil -> 0
      key -> Map.get(data_map, key, 0)
    end
  end

  defp hour_bucket_count(_data_map, _hour), do: 0

  defp truncate_utc_hour(%DateTime{} = dt) do
    %{dt | minute: 0, second: 0, microsecond: {0, 0}}
  end

  defp truncate_utc_hour(_), do: nil

  defp normalize_count(count) when is_struct(count, Decimal), do: Decimal.to_integer(count)
  defp normalize_count(count) when is_integer(count), do: count
  defp normalize_count(count) when is_float(count), do: trunc(count)

  defp normalize_count(count) do
    trunc(count)
  rescue
    _ -> 0
  end

  # Wrapper function to query hourly data and convert to map
  defp query_hourly_data(repo, sql, params) do
    params =
      Enum.map(params, fn
        %DateTime{} = dt -> DateTime.to_naive(dt)
        other -> other
      end)

    # Use SQL.query which provides better type decoding
    case SQL.query(repo, sql, params) do
      {:ok, %{rows: rows}} ->
        Enum.reduce(rows, %{}, fn row, acc ->
          case process_hourly_row(row) do
            nil ->
              acc

            {hour, count} ->
              case truncate_utc_hour(hour) do
                nil ->
                  acc

                key ->
                  n = normalize_count(count)
                  Map.update(acc, key, n, &(&1 + n))
              end
          end
        end)

      _ ->
        %{}
    end
  end

  # Process a single row from hourly query: [hour, count] -> {DateTime, count} | nil
  defp process_hourly_row([hour, count]) do
    # First, check if hour is a valid datetime struct - if so, process it directly
    cond do
      is_struct(hour, DateTime) ->
        try do
          {%{hour | minute: 0, second: 0, microsecond: {0, 0}}, count}
        rescue
          _ -> nil
        end

      is_struct(hour, NaiveDateTime) ->
        try do
          dt = DateTime.from_naive!(hour, "Etc/UTC")
          {%{dt | minute: 0, second: 0, microsecond: {0, 0}}, count}
        rescue
          _ -> nil
        end

      # Skip any 2-tuples with integers - these are NOT timestamps
      is_tuple(hour) and tuple_size(hour) == 2 ->
        case hour do
          {a, b} when is_integer(a) and is_integer(b) ->
            # Skip invalid tuples like {0, 6} or {487063, 6}
            nil

          _ ->
            # Might be a date/time tuple {{y,m,d}, {h,min,s}}, try to convert
            case DatetimeHelpers.convert_to_datetime(hour) do
              {:ok, dt} when is_struct(dt, DateTime) ->
                # Final safety check - ensure dt is actually a DateTime struct
                if is_struct(dt, DateTime) do
                  try do
                    {%{dt | minute: 0, second: 0, microsecond: {0, 0}}, count}
                  rescue
                    _ -> nil
                  end
                else
                  nil
                end

              _ ->
                nil
            end
        end

      # Not a tuple or struct, try to convert
      true ->
        case DatetimeHelpers.convert_to_datetime(hour) do
          {:ok, dt} when is_struct(dt, DateTime) ->
            # Final safety check - ensure dt is actually a DateTime struct
            if is_struct(dt, DateTime) do
              try do
                {%{dt | minute: 0, second: 0, microsecond: {0, 0}}, count}
              rescue
                _ -> nil
              end
            else
              nil
            end

          _ ->
            nil
        end
    end
  end
end
