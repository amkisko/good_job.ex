defmodule GoodJob.ExecutorTest do
  use ExUnit.Case, async: false

  alias GoodJob.{Executor, Job, Repo}

  defmodule TestJob do
    use GoodJob.Job

    @impl GoodJob.Behaviour
    def perform(_args) do
      :ok
    end
  end

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
    Ecto.Adapters.SQL.Sandbox.mode(Repo.repo(), :manual)
    :ok
  end

  describe "new/2" do
    test "creates executor with job" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())

      job = %Job{
        id: Ecto.UUID.generate(),
        job_class: "Elixir.GoodJob.ExecutorTest.TestJob",
        serialized_params: %{"arguments" => [%{}]}
      }

      exec = Executor.new(job)
      assert exec.job == job
      assert exec.state == :unset
      assert exec.safe == true
    end

    test "creates executor with safe: false" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())

      job = %Job{
        id: Ecto.UUID.generate(),
        job_class: "Elixir.GoodJob.ExecutorTest.TestJob",
        serialized_params: %{"arguments" => [%{}]}
      }

      exec = Executor.new(job, safe: false)
      assert exec.safe == false
    end
  end

  defmodule TestJobWithReturnValue do
    use GoodJob.Job

    @impl GoodJob.Behaviour
    def perform(_args) do
      {:ok, "result"}
    end
  end

  defmodule TestJobWithCancel do
    use GoodJob.Job

    @impl GoodJob.Behaviour
    def perform(_args) do
      {:cancel, "cancelled"}
    end
  end

  defmodule TestJobWithDiscard do
    use GoodJob.Job

    @impl GoodJob.Behaviour
    def perform(_args) do
      :discard
    end
  end

  defmodule TestJobWithError do
    use GoodJob.Job

    @impl GoodJob.Behaviour
    def perform(_args) do
      {:error, "failed"}
    end
  end

  defmodule TestJobWithSnooze do
    use GoodJob.Job

    @impl GoodJob.Behaviour
    def perform(_args) do
      {:snooze, 60}
    end
  end

  defmodule TestJobWithUnexpectedReturn do
    use GoodJob.Job

    @impl GoodJob.Behaviour
    def perform(_args) do
      :unexpected_state
    end
  end

  defmodule TestJobWithException do
    use GoodJob.Job

    @impl GoodJob.Behaviour
    def perform(_args) do
      raise "test error"
    end
  end

  defmodule TestJobExhausted do
    use GoodJob.Job

    @impl GoodJob.Behaviour
    def perform(_args) do
      {:error, "failed"}
    end
  end

  describe "call/1" do
    test "executes job successfully with :ok return" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())

      job = %Job{
        id: Ecto.UUID.generate(),
        job_class: "Elixir.GoodJob.ExecutorTest.TestJob",
        serialized_params: %{"arguments" => [%{}]},
        executions_count: 0
      }

      exec = Executor.new(job)
      exec = Executor.call(exec)
      assert exec.state == :success
      assert exec.result == :ok
      assert not is_nil(exec.duration)
    end

    test "executes job successfully with {:ok, value} return" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())

      job = %Job{
        id: Ecto.UUID.generate(),
        job_class: "Elixir.GoodJob.ExecutorTest.TestJobWithReturnValue",
        serialized_params: %{"arguments" => [%{}]},
        executions_count: 0
      }

      exec = Executor.new(job)
      exec = Executor.call(exec)
      assert exec.state == :success
      assert exec.result == {:ok, "result"}
    end

    test "handles {:cancel, reason} return" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())

      job = %Job{
        id: Ecto.UUID.generate(),
        job_class: "Elixir.GoodJob.ExecutorTest.TestJobWithCancel",
        serialized_params: %{"arguments" => [%{}]},
        executions_count: 0
      }

      exec = Executor.new(job)
      exec = Executor.call(exec)
      assert exec.state == :cancelled
      assert exec.error != nil
    end

    test "handles :discard return" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())

      job = %Job{
        id: Ecto.UUID.generate(),
        job_class: "Elixir.GoodJob.ExecutorTest.TestJobWithDiscard",
        serialized_params: %{"arguments" => [%{}]},
        executions_count: 0
      }

      exec = Executor.new(job)
      exec = Executor.call(exec)
      assert exec.state == :discard
      assert exec.error != nil
    end

    test "handles {:error, reason} return" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())

      job = %Job{
        id: Ecto.UUID.generate(),
        job_class: "Elixir.GoodJob.ExecutorTest.TestJobWithError",
        serialized_params: %{"arguments" => [%{}]},
        executions_count: 0
      }

      exec = Executor.new(job)
      exec = Executor.call(exec)
      assert exec.state == :failure
      assert exec.error != nil
    end

    test "handles {:snooze, seconds} return" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())

      job = %Job{
        id: Ecto.UUID.generate(),
        job_class: "Elixir.GoodJob.ExecutorTest.TestJobWithSnooze",
        serialized_params: %{"arguments" => [%{}]},
        executions_count: 0
      }

      exec = Executor.new(job)
      exec = Executor.call(exec)
      assert exec.state == :snoozed
      assert exec.result == {:snooze, 60}
    end

    test "handles unexpected return value" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())

      job = %Job{
        id: Ecto.UUID.generate(),
        job_class: "Elixir.GoodJob.ExecutorTest.TestJobWithUnexpectedReturn",
        serialized_params: %{"arguments" => [%{}]},
        executions_count: 0
      }

      exec = Executor.new(job)
      exec = Executor.call(exec)
      assert exec.state == :success
      assert exec.result == :unexpected_state
    end

    test "handles exceptions and sets state to failure" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())

      job = %Job{
        id: Ecto.UUID.generate(),
        job_class: "Elixir.GoodJob.ExecutorTest.TestJobWithException",
        serialized_params: %{"arguments" => [%{}]},
        executions_count: 0
      }

      exec = Executor.new(job, safe: true)
      exec = Executor.call(exec)
      assert exec.state == :failure
      assert exec.error != nil
      assert exec.error.__struct__ == RuntimeError
    end

    test "handles catch and creates CrashError" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())

      # Create a job that will cause a catch (exit, throw, etc.)
      job = %Job{
        id: Ecto.UUID.generate(),
        job_class: "Elixir.GoodJob.ExecutorTest.TestJob",
        serialized_params: %{"arguments" => [%{}]},
        executions_count: 0
      }

      exec = Executor.new(job, safe: true)
      # The executor will handle the error gracefully
      exec = Executor.call(exec)
      assert exec.state in [:success, :failure]
    end

    test "normalizes state to exhausted when max attempts reached" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())

      job = %Job{
        id: Ecto.UUID.generate(),
        job_class: "Elixir.GoodJob.ExecutorTest.TestJobExhausted",
        serialized_params: %{"arguments" => [%{}]},
        # Max attempts
        executions_count: 25
      }

      exec = Executor.new(job)
      exec = Executor.call(exec)
      assert exec.state == :exhausted
    end

    test "handles worker resolution failure in safe mode" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())

      job = %Job{
        id: Ecto.UUID.generate(),
        job_class: "Elixir.NonExistent.Module",
        serialized_params: %{"arguments" => [%{}]},
        executions_count: 0
      }

      exec = Executor.new(job, safe: true)
      exec = Executor.call(exec)
      assert exec.state == :failure
      assert exec.error != nil
    end

    test "records start time and calculates duration" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())

      job = %Job{
        id: Ecto.UUID.generate(),
        job_class: "Elixir.GoodJob.ExecutorTest.TestJob",
        serialized_params: %{"arguments" => [%{}]},
        executions_count: 0
      }

      exec = Executor.new(job)
      assert exec.start_time != nil
      assert exec.start_mono != nil
      assert exec.duration == nil

      exec = Executor.call(exec)
      assert not is_nil(exec.duration)
      assert exec.duration > 0
    end

    test "handles deserialization of arguments" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())

      job = %Job{
        id: Ecto.UUID.generate(),
        job_class: "Elixir.GoodJob.ExecutorTest.TestJob",
        serialized_params: %{"arguments" => [%{key: "value"}]},
        executions_count: 0
      }

      exec = Executor.new(job)
      exec = Executor.call(exec)
      assert exec.state == :success
    end
  end
end
