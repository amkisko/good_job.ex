defmodule GoodJob.InterruptErrorTest do
  use ExUnit.Case, async: true

  alias GoodJob.InterruptError

  test "raises with default message" do
    assert_raise InterruptError, "Job was interrupted", fn ->
      raise InterruptError
    end
  end

  test "raises with custom message" do
    assert_raise InterruptError, "Custom interrupt message", fn ->
      raise InterruptError, message: "Custom interrupt message"
    end
  end

  test "exception struct has message field" do
    exception = %InterruptError{message: "Test message"}
    assert exception.message == "Test message"
  end

  test "Exception.message/1 returns the message" do
    exception = %InterruptError{message: "Test message"}
    assert Exception.message(exception) == "Test message"
  end

  test "can be raised and caught" do
    try do
      raise InterruptError, message: "Caught error"
    rescue
      e in InterruptError ->
        assert e.message == "Caught error"
        assert Exception.message(e) == "Caught error"
    end
  end
end
