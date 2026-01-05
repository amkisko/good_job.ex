defmodule GoodJob.ExternalJobTest do
  use ExUnit.Case, async: false
  use GoodJob.Testing.JobCase

  alias GoodJob.ExternalJob

  defmodule TestExternalJob do
    use ExternalJob, queue: "payments", priority: 5
  end

  describe "__using__/1" do
    test "defines an ExternalJob module" do
      # ExternalJob module should be defined with queue and priority
      assert function_exported?(TestExternalJob, :__good_job_queue__, 0)
      assert function_exported?(TestExternalJob, :__good_job_priority__, 0)
    end

    test "sets default queue" do
      assert function_exported?(TestExternalJob, :__good_job_queue__, 0)
      queue = TestExternalJob.__good_job_queue__()
      assert queue == "payments"
    end

    test "sets default priority" do
      assert function_exported?(TestExternalJob, :__good_job_priority__, 0)
      assert TestExternalJob.__good_job_priority__() == 5
    end
  end

  describe "enqueue/2" do
    test "enqueues job with queue name" do
      repo = Repo.repo()

      repo.transaction(fn ->
        result = TestExternalJob.enqueue(%{data: "test"})
        assert match?({:ok, _job}, result)
        {:ok, job} = result
        assert job.queue_name == "payments"
      end)
    end
  end

  describe "module_to_external_class/1" do
    test "converts Elixir module to external class name" do
      result = ExternalJob.module_to_external_class(TestExternalJob)
      assert is_binary(result)
      assert String.contains?(result, "::")
    end

    test "handles string input" do
      result = ExternalJob.module_to_external_class("MyApp.ProcessPaymentJob")
      assert result == "MyApp::ProcessPaymentJob"
    end
  end

  describe "LocalExecutionError" do
    test "raises when trying to execute inline via enqueue" do
      # ExternalJob should prevent inline execution
      assert_raise ExternalJob.LocalExecutionError, fn ->
        TestExternalJob.enqueue(%{data: "test"}, execution_mode: :inline)
      end
    end

    test "raises when trying to call perform directly" do
      # ExternalJob perform/1 raises LocalExecutionError
      assert_raise ExternalJob.LocalExecutionError, fn ->
        TestExternalJob.perform(%{data: "test"})
      end
    end
  end

  describe "perform_later/1 with pattern matching" do
    defmodule PatternMatchedJob do
      use ExternalJob, queue: "validated"

      # Override with pattern matching for argument validation
      def perform_later(%{user_id: user_id, amount: amount}) when is_integer(user_id) and is_float(amount) do
        super(%{user_id: user_id, amount: amount})
      end
    end

    test "validates arguments with pattern matching" do
      repo = Repo.repo()

      repo.transaction(fn ->
        # Valid arguments should work
        result = PatternMatchedJob.perform_later(%{user_id: 123, amount: 100.0})
        assert match?({:ok, _job}, result)
      end)
    end

    test "raises FunctionClauseError for invalid arguments" do
      repo = Repo.repo()

      repo.transaction(fn ->
        # Invalid arguments should raise FunctionClauseError
        assert_raise FunctionClauseError, fn ->
          PatternMatchedJob.perform_later(%{user_id: "invalid", amount: 100.0})
        end

        assert_raise FunctionClauseError, fn ->
          PatternMatchedJob.perform_later(%{user_id: 123, amount: "invalid"})
        end

        assert_raise FunctionClauseError, fn ->
          PatternMatchedJob.perform_later(%{missing: "fields"})
        end
      end)
    end
  end
end
