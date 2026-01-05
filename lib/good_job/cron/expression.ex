defmodule GoodJob.Cron.Expression do
  @moduledoc """
  Parses and evaluates cron expressions.

  Supports standard cron syntax: minute hour day month weekday
  Also supports nicknames: @yearly, @monthly, @weekly, @daily, @hourly, @reboot
  """

  @type t :: %__MODULE__{
          input: String.t(),
          minutes: MapSet.t(integer()),
          hours: MapSet.t(integer()),
          days: MapSet.t(integer()),
          months: MapSet.t(integer()),
          weekdays: MapSet.t(integer()),
          reboot?: boolean()
        }

  defstruct [:input, :minutes, :hours, :days, :months, :weekdays, reboot?: false]

  @nicknames %{
    "@yearly" => "0 0 1 1 *",
    "@annually" => "0 0 1 1 *",
    "@monthly" => "0 0 1 * *",
    "@weekly" => "0 0 * * 0",
    "@daily" => "0 0 * * *",
    "@midnight" => "0 0 * * *",
    "@hourly" => "0 * * * *",
    "@reboot" => :reboot
  }

  @min_range 0..59
  @hrs_range 0..23
  @day_range 1..31
  @mon_range 1..12
  @dow_range 0..6

  @doc """
  Parses a cron expression string.

  Returns `{:ok, expression}` or `{:error, reason}`.
  """
  @spec parse(String.t()) :: {:ok, t()} | {:error, String.t()}
  def parse(input) when is_binary(input) do
    normalized = normalize_nickname(input)

    case normalized do
      :reboot ->
        {:ok, %__MODULE__{input: input, reboot?: true}}

      expr ->
        case String.split(expr, " ", trim: true) do
          [min, hour, day, month, dow] ->
            with {:ok, minutes} <- parse_field(min, @min_range),
                 {:ok, hours} <- parse_field(hour, @hrs_range),
                 {:ok, days} <- parse_field(day, @day_range),
                 {:ok, months} <- parse_field(month, @mon_range),
                 {:ok, weekdays} <- parse_field(dow, @dow_range) do
              {:ok,
               %__MODULE__{
                 input: input,
                 minutes: minutes,
                 hours: hours,
                 days: days,
                 months: months,
                 weekdays: weekdays
               }}
            end

          _ ->
            {:error, "Invalid cron expression: expected 5 fields"}
        end
    end
  end

  @doc """
  Parses a cron expression and raises on error.
  """
  @spec parse!(String.t()) :: t()
  def parse!(input) do
    case parse(input) do
      {:ok, expr} -> expr
      {:error, reason} -> raise ArgumentError, message: reason
    end
  end

  @doc """
  Checks if the cron expression matches the current time.
  """
  @spec now?(t(), DateTime.t()) :: boolean()
  def now?(%__MODULE__{reboot?: true}, _datetime), do: true

  def now?(%__MODULE__{} = cron, datetime) do
    dow = day_of_week(datetime)

    MapSet.member?(cron.months, datetime.month) and
      MapSet.member?(cron.weekdays, dow) and
      MapSet.member?(cron.days, datetime.day) and
      MapSet.member?(cron.hours, datetime.hour) and
      MapSet.member?(cron.minutes, datetime.minute)
  end

  @doc """
  Returns the next DateTime that matches the cron expression.
  """
  @spec next_at(t(), DateTime.t()) :: DateTime.t()
  def next_at(expr, time \\ DateTime.utc_now()) do
    if expr.reboot? do
      time
    else
      time
      |> DateTime.add(1, :minute)
      |> DateTime.truncate(:second)
      |> Map.put(:second, 0)
      |> match_at(expr, :next)
    end
  end

  defp normalize_nickname(input) do
    # Try original case first, then uppercase
    case Map.get(@nicknames, input) do
      nil ->
        upcased = String.upcase(input)
        Map.get(@nicknames, upcased, input)

      result ->
        result
    end
  end

  defp parse_field("*", range), do: {:ok, MapSet.new(range)}

  defp parse_field(field, range) do
    field
    |> String.split(",")
    |> Enum.reduce_while({:ok, MapSet.new()}, fn part, {:ok, acc} ->
      case parse_field_part(part, range) do
        {:ok, values} -> {:cont, {:ok, MapSet.union(acc, values)}}
        error -> {:halt, error}
      end
    end)
  end

  defp parse_field_part(part, range) do
    cond do
      String.contains?(part, "/") ->
        parse_step(part, range)

      String.contains?(part, "-") ->
        parse_range(part, range)

      true ->
        case Integer.parse(part) do
          {value, ""} ->
            if value in range do
              {:ok, MapSet.new([value])}
            else
              {:error, "Value #{value} out of range #{inspect(range)}"}
            end

          _ ->
            {:error, "Invalid field value: #{part}"}
        end
    end
  end

  defp parse_range(range_str, range) do
    case String.split(range_str, "-") do
      [start_str, end_str] ->
        with {start, ""} <- Integer.parse(start_str),
             {ending, ""} <- Integer.parse(end_str),
             true <- start in range,
             true <- ending in range,
             true <- start <= ending do
          {:ok, MapSet.new(start..ending)}
        else
          _ -> {:error, "Invalid range: #{range_str}"}
        end

      _ ->
        {:error, "Invalid range format: #{range_str}"}
    end
  end

  defp parse_step(step_str, range) do
    case String.split(step_str, "/") do
      [base, step_str] ->
        step =
          case Integer.parse(step_str) do
            {s, ""} -> s
            _ -> {:error, "Invalid step: #{step_str}"}
          end

        case step do
          {:error, _} = error ->
            error

          s when s > 0 ->
            base_set =
              if base == "*" do
                MapSet.new(range)
              else
                case parse_field_part(base, range) do
                  {:ok, set} -> set
                  _error -> {:error, "Invalid base in step: #{base}"}
                end
              end

            case base_set do
              {:error, _} = error ->
                error

              set ->
                values =
                  set
                  |> Enum.filter(&(rem(&1, s) == 0))
                  |> MapSet.new()

                {:ok, values}
            end

          _ ->
            {:error, "Step must be positive: #{step_str}"}
        end

      _ ->
        {:error, "Invalid step format: #{step_str}"}
    end
  end

  defp match_at(time, expr, dir) do
    cond do
      now?(expr, time) ->
        time

      not MapSet.member?(expr.months, time.month) ->
        match_at(bump_month(expr, time, dir), expr, dir)

      not MapSet.member?(expr.days, time.day) ->
        match_at(bump_day(expr, time, dir), expr, dir)

      not MapSet.member?(expr.hours, time.hour) ->
        match_at(bump_hour(expr, time, dir), expr, dir)

      true ->
        match_at(bump_minute(expr, time, dir), expr, dir)
    end
  end

  defp bump_month(expr, time, :next) do
    case find_next(expr.months, time.month) do
      nil -> %{time | month: 1, day: 1, hour: 0, minute: 0, year: time.year + 1}
      month -> %{time | month: month, day: 1, hour: 0, minute: 0}
    end
  end

  defp bump_day(expr, time, :next) do
    days_in_month = days_in_month(time.year, time.month)

    case find_next(expr.days, time.day) do
      nil -> bump_month(expr, time, :next)
      day when day > days_in_month -> bump_month(expr, time, :next)
      day -> %{time | day: day, hour: 0, minute: 0}
    end
  end

  defp bump_hour(expr, time, :next) do
    case find_next(expr.hours, time.hour) do
      nil -> bump_day(expr, time, :next)
      hour -> %{time | hour: hour, minute: 0}
    end
  end

  defp bump_minute(expr, time, :next) do
    case find_next(expr.minutes, time.minute) do
      nil -> bump_hour(expr, time, :next)
      minute -> %{time | minute: minute}
    end
  end

  defp find_next(set, value) do
    set
    |> Enum.sort()
    |> Enum.find(&(&1 > value))
  end

  defp day_of_week(datetime) do
    :calendar.day_of_the_week(datetime.year, datetime.month, datetime.day) - 1
  end

  defp days_in_month(year, month) do
    :calendar.last_day_of_the_month(year, month)
  end
end
