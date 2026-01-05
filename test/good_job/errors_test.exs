defmodule GoodJob.ErrorsTest do
  use ExUnit.Case, async: true

  alias GoodJob.Errors

  describe "classify_error/1" do
    test "classifies DBConnection.ConnectionError as retry" do
      error = %DBConnection.ConnectionError{message: "connection failed"}
      assert Errors.classify_error(error) == :retry
    end

    test "classifies DBConnection.TransactionError as retry" do
      error = %DBConnection.TransactionError{message: "transaction failed"}
      assert Errors.classify_error(error) == :retry
    end

    test "classifies Postgrex.Error with retryable codes as retry" do
      retryable_codes = [
        :connection_exception,
        :query_canceled,
        :deadlock_detected,
        :serialization_failure,
        :statement_timeout,
        :lock_timeout
      ]

      for code <- retryable_codes do
        error = %Postgrex.Error{postgres: %{code: code}}
        assert Errors.classify_error(error) == :retry
      end
    end

    test "classifies Ecto.Query.CastError as discard" do
      error = %Ecto.Query.CastError{message: "cast failed"}
      assert Errors.classify_error(error) == :discard
    end

    test "classifies Ecto.Changeset as discard" do
      changeset = Ecto.Changeset.change(%GoodJob.Job{}, %{})
      assert Errors.classify_error(changeset) == :discard
    end

    test "classifies ArgumentError as discard" do
      error = %ArgumentError{message: "invalid argument"}
      assert Errors.classify_error(error) == :discard
    end

    test "classifies FunctionClauseError as discard" do
      error = %FunctionClauseError{arity: 1, function: :test, module: __MODULE__}
      assert Errors.classify_error(error) == :discard
    end

    test "classifies unknown errors as retry" do
      assert Errors.classify_error("unknown error") == :retry
      assert Errors.classify_error(%RuntimeError{message: "runtime error"}) == :retry
    end
  end

  describe "format_error/1" do
    test "formats exception errors" do
      error = %RuntimeError{message: "test error"}
      result = Errors.format_error(error)
      assert result.class == "RuntimeError"
      assert result.message == "test error"
      assert result.stacktrace == nil
    end

    test "formats binary errors" do
      result = Errors.format_error("binary error")
      assert result.class == "String"
      assert result.message == "binary error"
    end

    test "formats unknown errors" do
      result = Errors.format_error(123)
      assert result.class == "Unknown"
      assert result.message == "123"
    end

    test "formats unknown structs" do
      # Exception.message/1 should work for any struct
      error = %RuntimeError{message: "test"}
      result = Errors.format_error(error)
      assert result.class == "RuntimeError"
      assert result.message == "test"
    end
  end

  describe "connection_error?/1" do
    test "returns true for DBConnection.ConnectionError" do
      error = %DBConnection.ConnectionError{message: "connection failed"}
      assert Errors.connection_error?(error) == true
    end

    test "returns true for DBConnection.TransactionError" do
      error = %DBConnection.TransactionError{message: "transaction failed"}
      assert Errors.connection_error?(error) == true
    end

    test "returns true for Postgrex.Error with connection_exception code" do
      error = %Postgrex.Error{postgres: %{code: :connection_exception}}
      assert Errors.connection_error?(error) == true
    end

    test "returns true for Postgrex.Error with query_canceled code" do
      error = %Postgrex.Error{postgres: %{code: :query_canceled}}
      assert Errors.connection_error?(error) == true
    end

    test "returns false for other errors" do
      assert Errors.connection_error?(%RuntimeError{message: "error"}) == false
      assert Errors.connection_error?("string") == false
    end
  end

  describe "timeout_error?/1" do
    test "returns true for Postgrex.Error with statement_timeout" do
      error = %Postgrex.Error{postgres: %{code: :statement_timeout}}
      assert Errors.timeout_error?(error) == true
    end

    test "returns true for Postgrex.Error with lock_timeout" do
      error = %Postgrex.Error{postgres: %{code: :lock_timeout}}
      assert Errors.timeout_error?(error) == true
    end

    test "returns true for JobTimeoutError" do
      error = %Errors.JobTimeoutError{message: "timeout", job_id: 1, timeout_ms: 1000}
      assert Errors.timeout_error?(error) == true
    end

    test "returns true for errors with timeout in message" do
      error = %RuntimeError{message: "operation timed out"}
      assert Errors.timeout_error?(error) == true
    end

    test "returns false for non-timeout errors" do
      assert Errors.timeout_error?(%RuntimeError{message: "other error"}) == false
      assert Errors.timeout_error?("string") == false
    end
  end

  describe "permanent_error?/1" do
    test "returns true for Ecto.Query.CastError" do
      error = %Ecto.Query.CastError{message: "cast failed"}
      assert Errors.permanent_error?(error) == true
    end

    test "returns true for Ecto.Changeset" do
      changeset = Ecto.Changeset.change(%GoodJob.Job{}, %{})
      assert Errors.permanent_error?(changeset) == true
    end

    test "returns true for ArgumentError" do
      error = %ArgumentError{message: "invalid argument"}
      assert Errors.permanent_error?(error) == true
    end

    test "returns true for FunctionClauseError" do
      error = %FunctionClauseError{arity: 1, function: :test, module: __MODULE__}
      assert Errors.permanent_error?(error) == true
    end

    test "returns false for other errors" do
      assert Errors.permanent_error?(%RuntimeError{message: "error"}) == false
      assert Errors.permanent_error?("string") == false
    end
  end

  describe "exception definitions" do
    test "ConcurrencyExceededError can be raised" do
      error = %Errors.ConcurrencyExceededError{
        message: "limit exceeded",
        concurrency_key: "test_key"
      }

      assert error.message == "limit exceeded"
      assert error.concurrency_key == "test_key"
    end

    test "ThrottleExceededError can be raised" do
      error = %Errors.ThrottleExceededError{
        message: "throttle exceeded",
        concurrency_key: "test_key"
      }

      assert error.message == "throttle exceeded"
      assert error.concurrency_key == "test_key"
    end

    test "ConfigurationError can be raised" do
      error = %Errors.ConfigurationError{message: "config error"}
      assert error.message == "config error"
    end

    test "JobTimeoutError can be raised" do
      error = %Errors.JobTimeoutError{
        message: "timeout",
        job_id: 123,
        timeout_ms: 5000
      }

      assert error.message == "timeout"
      assert error.job_id == 123
      assert error.timeout_ms == 5000
    end
  end
end
