defmodule GoodJob.Cron.ExpressionTest do
  use ExUnit.Case, async: true

  alias GoodJob.Cron.Expression

  describe "parse/1" do
    test "parses standard cron expression" do
      assert {:ok, expr} = Expression.parse("0 0 * * *")
      assert expr.minutes == MapSet.new([0])
      assert expr.hours == MapSet.new([0])
    end

    test "parses cron with specific values" do
      assert {:ok, expr} = Expression.parse("30 14 * * *")
      assert MapSet.member?(expr.minutes, 30)
      assert MapSet.member?(expr.hours, 14)
    end

    test "parses cron with ranges" do
      assert {:ok, expr} = Expression.parse("0 9-17 * * *")
      assert MapSet.member?(expr.hours, 9)
      assert MapSet.member?(expr.hours, 17)
    end

    test "parses cron with steps" do
      assert {:ok, expr} = Expression.parse("*/15 * * * *")
      assert MapSet.member?(expr.minutes, 0)
      assert MapSet.member?(expr.minutes, 15)
      assert MapSet.member?(expr.minutes, 30)
      assert MapSet.member?(expr.minutes, 45)
    end

    test "parses cron with lists" do
      assert {:ok, expr} = Expression.parse("0 0,12 * * *")
      assert MapSet.member?(expr.hours, 0)
      assert MapSet.member?(expr.hours, 12)
    end

    test "parses @yearly nickname" do
      assert {:ok, expr} = Expression.parse("@yearly")
      assert expr.input == "@yearly"
      assert expr.minutes == MapSet.new([0])
      assert expr.hours == MapSet.new([0])
    end

    test "parses @monthly nickname" do
      assert {:ok, expr} = Expression.parse("@monthly")
      assert expr.input == "@monthly"
    end

    test "parses @weekly nickname" do
      assert {:ok, expr} = Expression.parse("@weekly")
      assert expr.input == "@weekly"
    end

    test "parses @daily nickname" do
      assert {:ok, expr} = Expression.parse("@daily")
      assert expr.input == "@daily"
    end

    test "parses @hourly nickname" do
      assert {:ok, expr} = Expression.parse("@hourly")
      assert expr.input == "@hourly"
    end

    test "parses @reboot nickname" do
      assert {:ok, expr} = Expression.parse("@reboot")
      assert expr.reboot? == true
    end

    test "returns error for invalid expression" do
      assert {:error, _} = Expression.parse("invalid")
    end

    test "returns error for wrong number of fields" do
      assert {:error, _} = Expression.parse("0 0 * *")
    end
  end

  describe "parse!/1" do
    test "parses valid expression" do
      expr = Expression.parse!("0 0 * * *")
      assert expr.minutes == MapSet.new([0])
    end

    test "raises for invalid expression" do
      assert_raise ArgumentError, fn ->
        Expression.parse!("invalid")
      end
    end
  end

  describe "now?/2" do
    test "returns true for reboot" do
      expr = %Expression{reboot?: true}
      assert Expression.now?(expr, DateTime.utc_now()) == true
    end

    test "checks if current time matches expression" do
      now = DateTime.utc_now()
      dow = :calendar.day_of_the_week(now.year, now.month, now.day) - 1

      expr = %Expression{
        minutes: MapSet.new([now.minute]),
        hours: MapSet.new([now.hour]),
        days: MapSet.new([now.day]),
        months: MapSet.new([now.month]),
        weekdays: MapSet.new([dow])
      }

      assert Expression.now?(expr, now) == true
    end
  end

  describe "next_at/2" do
    test "calculates next execution time" do
      expr = Expression.parse!("0 * * * *")
      now = DateTime.utc_now()
      next = Expression.next_at(expr, now)
      assert DateTime.compare(next, now) in [:gt, :eq]
    end

    test "handles reboot expression" do
      {:ok, expr} = Expression.parse("@reboot")
      now = DateTime.utc_now()
      next = Expression.next_at(expr, now)
      assert next == now
    end
  end
end
