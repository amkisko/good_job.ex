defmodule GoodJob.JobStats.DatetimeHelpersTest do
  use ExUnit.Case, async: true

  alias GoodJob.JobStats.DatetimeHelpers

  describe "convert_to_datetime/1" do
    test "converts NaiveDateTime to DateTime" do
      naive_dt = ~N[2024-01-01 12:00:00]
      {:ok, dt} = DatetimeHelpers.convert_to_datetime(naive_dt)
      assert %DateTime{} = dt
    end

    test "returns DateTime as-is" do
      dt = DateTime.utc_now()
      {:ok, result} = DatetimeHelpers.convert_to_datetime(dt)
      assert result == dt
    end

    test "converts Date to DateTime" do
      date = ~D[2024-01-01]
      {:ok, dt} = DatetimeHelpers.convert_to_datetime(date)
      assert %DateTime{} = dt
    end

    test "rejects integer tuples" do
      assert DatetimeHelpers.convert_to_datetime({0, 6}) == :error
      assert DatetimeHelpers.convert_to_datetime({487_063, 6}) == :error
    end

    test "converts Erlang date/time tuple" do
      erlang_dt = {{2024, 1, 1}, {12, 0, 0}}
      {:ok, dt} = DatetimeHelpers.convert_to_datetime(erlang_dt)
      assert %DateTime{} = dt
    end

    test "converts ISO8601 string" do
      iso_string = "2024-01-01T12:00:00Z"
      {:ok, dt} = DatetimeHelpers.convert_to_datetime(iso_string)
      assert %DateTime{} = dt
    end

    test "rejects invalid string" do
      assert DatetimeHelpers.convert_to_datetime("invalid") == :error
    end

    test "rejects other tuples" do
      assert DatetimeHelpers.convert_to_datetime({:atom, :value}) == :error
    end

    test "rejects other types" do
      assert DatetimeHelpers.convert_to_datetime(123) == :error
      assert DatetimeHelpers.convert_to_datetime(:atom) == :error
    end
  end

  describe "format_hour/1" do
    test "formats datetime by slicing to 16 characters" do
      dt = ~U[2024-01-01 12:34:56.789Z]
      formatted = DatetimeHelpers.format_hour(dt)
      # format_hour slices the string to 16 chars, so "2024-01-01 12:34:56" becomes "2024-01-01 12:34"
      assert formatted == "2024-01-01 12:34"
    end
  end
end
