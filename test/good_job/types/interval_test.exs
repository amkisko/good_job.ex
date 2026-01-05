defmodule GoodJob.Types.IntervalTest do
  use ExUnit.Case, async: true

  alias GoodJob.Types.Interval

  describe "type/0" do
    test "returns :interval" do
      assert Interval.type() == :interval
    end
  end

  describe "cast/1" do
    test "casts Postgrex.Interval" do
      interval = %Postgrex.Interval{months: 0, days: 0, secs: 5, microsecs: 0}
      assert Interval.cast(interval) == {:ok, interval}
    end

    test "casts integer seconds" do
      assert {:ok, interval} = Interval.cast(5)
      assert interval.secs == 5
      assert interval.microsecs == 0
    end

    test "casts float seconds" do
      assert {:ok, interval} = Interval.cast(5.5)
      assert interval.secs == 5
      assert interval.microsecs == 500_000
    end

    test "casts string with seconds" do
      assert {:ok, interval} = Interval.cast("5 seconds")
      assert interval.secs == 5
    end

    test "casts string with decimal seconds" do
      assert {:ok, interval} = Interval.cast("0.11753 seconds")
      assert interval.secs == 0
      assert interval.microsecs == 117_530
    end

    test "casts string without 'seconds' suffix" do
      assert {:ok, interval} = Interval.cast("5")
      assert interval.secs == 5
    end

    test "returns error for invalid input" do
      assert Interval.cast(:invalid) == :error
      assert Interval.cast([]) == :error
    end
  end

  describe "load/1" do
    test "loads Postgrex.Interval" do
      interval = %Postgrex.Interval{months: 0, days: 0, secs: 5, microsecs: 0}
      assert Interval.load(interval) == {:ok, interval}
    end

    test "returns error for invalid input" do
      assert Interval.load("invalid") == :error
    end
  end

  describe "dump/1" do
    test "dumps Postgrex.Interval" do
      interval = %Postgrex.Interval{months: 0, days: 0, secs: 5, microsecs: 0}
      assert Interval.dump(interval) == {:ok, interval}
    end

    test "returns error for invalid input" do
      assert Interval.dump("invalid") == :error
    end
  end

  describe "equal?/2" do
    test "returns true for equal intervals" do
      interval1 = %Postgrex.Interval{months: 0, days: 0, secs: 5, microsecs: 0}
      interval2 = %Postgrex.Interval{months: 0, days: 0, secs: 5, microsecs: 0}
      assert Interval.equal?(interval1, interval2) == true
    end

    test "returns false for different intervals" do
      interval1 = %Postgrex.Interval{months: 0, days: 0, secs: 5, microsecs: 0}
      interval2 = %Postgrex.Interval{months: 0, days: 0, secs: 6, microsecs: 0}
      assert Interval.equal?(interval1, interval2) == false
    end

    test "returns false for non-interval values" do
      assert Interval.equal?(%Postgrex.Interval{}, "invalid") == false
      assert Interval.equal?("invalid", "invalid") == false
    end
  end

  describe "embed_as/1" do
    test "returns :self" do
      assert Interval.embed_as(:anything) == :self
    end
  end
end
