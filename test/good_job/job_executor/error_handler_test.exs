defmodule GoodJob.JobExecutor.ErrorHandlerTest do
  use ExUnit.Case, async: true

  alias GoodJob.JobExecutor.ErrorHandler

  defmodule TestJobWithDiscardOn do
    @behaviour GoodJob.Behaviour

    def perform(_args), do: :ok

    def __good_job_discard_on__ do
      [ArgumentError, RuntimeError]
    end
  end

  defmodule TestJobWithoutDiscardOn do
    @behaviour GoodJob.Behaviour

    def perform(_args), do: :ok
  end

  describe "check_discard_on/2" do
    test "returns false when job_module is nil" do
      assert ErrorHandler.check_discard_on(nil, %RuntimeError{message: "test"}) == false
    end

    test "returns false when job module has no discard_on configuration" do
      error = %RuntimeError{message: "test"}
      assert ErrorHandler.check_discard_on(TestJobWithoutDiscardOn, error) == false
    end

    test "returns true when error matches discard_on exception" do
      error = %ArgumentError{message: "invalid argument"}
      assert ErrorHandler.check_discard_on(TestJobWithDiscardOn, error) == true

      error2 = %RuntimeError{message: "runtime error"}
      assert ErrorHandler.check_discard_on(TestJobWithDiscardOn, error2) == true
    end

    test "returns false when error does not match discard_on exception" do
      error = %KeyError{key: :missing, term: %{}}
      assert ErrorHandler.check_discard_on(TestJobWithDiscardOn, error) == false

      error2 = %FunctionClauseError{}
      assert ErrorHandler.check_discard_on(TestJobWithDiscardOn, error2) == false

      error3 = %ArithmeticError{}
      assert ErrorHandler.check_discard_on(TestJobWithDiscardOn, error3) == false
    end

    test "handles multiple exceptions in discard_on list" do
      error1 = %ArgumentError{message: "test"}
      error2 = %RuntimeError{message: "test"}
      error3 = %KeyError{key: :missing, term: %{}}

      assert ErrorHandler.check_discard_on(TestJobWithDiscardOn, error1) == true
      assert ErrorHandler.check_discard_on(TestJobWithDiscardOn, error2) == true
      assert ErrorHandler.check_discard_on(TestJobWithDiscardOn, error3) == false
    end
  end
end
