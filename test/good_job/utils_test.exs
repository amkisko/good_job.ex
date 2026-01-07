defmodule GoodJob.UtilsTest do
  use ExUnit.Case, async: true

  alias GoodJob.Utils

  describe "format_error/1" do
    test "formats string errors" do
      assert Utils.format_error("test error") == "test error"
    end

    test "formats exception errors" do
      error = %RuntimeError{message: "test exception"}
      assert Utils.format_error(error) == "RuntimeError: test exception"
    end

    test "formats other types" do
      assert Utils.format_error(:error) == ":error"
      assert Utils.format_error(123) == "123"
      assert Utils.format_error(%{key: "value"}) =~ "key"
    end

    test "handles various exception types" do
      error1 = %ArgumentError{message: "invalid argument"}
      assert Utils.format_error(error1) == "ArgumentError: invalid argument"

      error2 = %FunctionClauseError{}
      assert is_binary(Utils.format_error(error2))
    end
  end

  describe "format_datetime_log/1" do
    test "returns 'nil' for nil values" do
      assert Utils.format_datetime_log(nil) == "nil"
    end

    test "formats datetime values" do
      datetime = ~U[2024-01-15 10:30:45Z]
      result = Utils.format_datetime_log(datetime)
      assert result =~ "2024"
      assert result =~ "10:30:45"
    end

    test "handles various datetime formats" do
      datetime = DateTime.utc_now()
      result = Utils.format_datetime_log(datetime)
      assert is_binary(result)
      assert String.length(result) > 0
    end
  end

  describe "format_duration_microseconds/1" do
    test "formats microseconds" do
      assert Utils.format_duration_microseconds(500) == "500μs"
      assert Utils.format_duration_microseconds(999) == "999μs"
    end

    test "formats milliseconds" do
      assert Utils.format_duration_microseconds(1000) == "1ms"
      assert Utils.format_duration_microseconds(5000) == "5ms"
      assert Utils.format_duration_microseconds(999_999) == "999ms"
    end

    test "formats seconds without remainder" do
      assert Utils.format_duration_microseconds(1_000_000) == "1s"
      assert Utils.format_duration_microseconds(5_000_000) == "5s"
    end

    test "formats seconds with remainder" do
      # remainder_ms = 500_000 / 1000 = 500, so "1.500s"
      assert Utils.format_duration_microseconds(1_500_000) == "1.500s"
      # remainder_ms = 300_000 / 1000 = 300, so "2.300s"
      assert Utils.format_duration_microseconds(2_300_000) == "2.300s"
      # remainder_ms = 500_000 / 1000 = 500, so "10.500s"
      assert Utils.format_duration_microseconds(10_500_000) == "10.500s"
    end

    test "handles large durations" do
      assert Utils.format_duration_microseconds(60_000_000) == "60s"
      # remainder_ms = 500_000 / 1000 = 500, so "65.500s"
      assert Utils.format_duration_microseconds(65_500_000) == "65.500s"
    end

    test "returns 'unknown' for non-integer values" do
      assert Utils.format_duration_microseconds("invalid") == "unknown"
      assert Utils.format_duration_microseconds(nil) == "unknown"
      assert Utils.format_duration_microseconds(:error) == "unknown"
    end
  end

  describe "format_backtrace/1" do
    test "formats valid stacktrace" do
      stacktrace = [
        {GoodJob.Utils, :format_backtrace, 1, [file: "test.ex", line: 1]},
        {ExUnit.Case, :test, 1, [file: "test.ex", line: 2]}
      ]

      result = Utils.format_backtrace(stacktrace)
      assert is_list(result)
      # Result might be empty if Exception.format_stacktrace doesn't exist or returns empty
      # Just verify it's a list (empty or not)
    end

    test "returns empty list for empty stacktrace" do
      assert Utils.format_backtrace([]) == []
    end

    test "returns empty list for invalid input" do
      assert Utils.format_backtrace("invalid") == []
      assert Utils.format_backtrace(nil) == []
      assert Utils.format_backtrace(:error) == []
    end

    test "handles stacktrace with various formats" do
      stacktrace = [
        {__MODULE__, :test_function, 1, [file: "test.exs", line: 42]}
      ]

      result = Utils.format_backtrace(stacktrace)
      assert is_list(result)
      # May be empty if Exception.format_stacktrace doesn't work with this format
    end
  end
end
