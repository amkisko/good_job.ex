defmodule GoodJob.JobCallbacksTest do
  use ExUnit.Case, async: true

  alias GoodJob.JobCallbacks

  defmodule JobWithCallbacks do
    def before_enqueue(args, _opts) do
      {:ok, Map.put(args, :before_enqueue_called, true)}
    end

    def after_enqueue(_job, _opts) do
      :ok
    end

    def before_perform(args, _job) do
      {:ok, Map.put(args, :before_perform_called, true)}
    end

    def after_perform(_args, _job, _result) do
      :ok
    end

    def on_error(_args, _job, _error) do
      :ok
    end
  end

  defmodule JobWithoutCallbacks do
  end

  describe "before_enqueue/3" do
    test "executes callback when defined" do
      args = %{test: "value"}
      assert {:ok, modified_args} = JobCallbacks.before_enqueue(JobWithCallbacks, args, [])
      assert modified_args.before_enqueue_called == true
    end

    test "returns args when callback not defined" do
      args = %{test: "value"}
      assert JobCallbacks.before_enqueue(JobWithoutCallbacks, args, []) == {:ok, args}
    end

    test "handles :ok return" do
      defmodule JobWithOkCallback do
        def before_enqueue(_args, _opts), do: :ok
      end

      args = %{test: "value"}
      assert JobCallbacks.before_enqueue(JobWithOkCallback, args, []) == {:ok, args}
    end

    test "handles error return" do
      defmodule JobWithErrorCallback do
        def before_enqueue(_args, _opts), do: {:error, "failed"}
      end

      args = %{test: "value"}
      assert JobCallbacks.before_enqueue(JobWithErrorCallback, args, []) == {:error, "failed"}
    end

    test "handles other return values" do
      defmodule JobWithOtherCallback do
        def before_enqueue(_args, _opts), do: %{modified: true}
      end

      args = %{test: "value"}
      assert {:ok, result} = JobCallbacks.before_enqueue(JobWithOtherCallback, args, [])
      assert result.modified == true
    end

    test "handles nil return" do
      defmodule JobWithNilCallback do
        def before_enqueue(_args, _opts), do: nil
      end

      args = %{test: "value"}
      assert {:ok, result} = JobCallbacks.before_enqueue(JobWithNilCallback, args, [])
      assert result == args
    end
  end

  describe "after_enqueue/3" do
    test "executes callback when defined" do
      job = %GoodJob.Job{id: Ecto.UUID.generate()}
      assert JobCallbacks.after_enqueue(JobWithCallbacks, job, []) == :ok
    end

    test "returns :ok when callback not defined" do
      job = %GoodJob.Job{id: Ecto.UUID.generate()}
      assert JobCallbacks.after_enqueue(JobWithoutCallbacks, job, []) == :ok
    end
  end

  describe "before_perform/3" do
    test "executes callback when defined" do
      args = %{test: "value"}
      job = %GoodJob.Job{id: Ecto.UUID.generate()}
      assert {:ok, modified_args} = JobCallbacks.before_perform(JobWithCallbacks, args, job)
      assert modified_args.before_perform_called == true
    end

    test "returns args when callback not defined" do
      args = %{test: "value"}
      job = %GoodJob.Job{id: Ecto.UUID.generate()}
      assert JobCallbacks.before_perform(JobWithoutCallbacks, args, job) == {:ok, args}
    end

    test "handles :ok return" do
      defmodule JobWithOkPerformCallback do
        def before_perform(_args, _job), do: :ok
      end

      args = %{test: "value"}
      job = %GoodJob.Job{id: Ecto.UUID.generate()}
      assert JobCallbacks.before_perform(JobWithOkPerformCallback, args, job) == {:ok, args}
    end

    test "handles error return" do
      defmodule JobWithErrorPerformCallback do
        def before_perform(_args, _job), do: {:error, "failed"}
      end

      args = %{test: "value"}
      job = %GoodJob.Job{id: Ecto.UUID.generate()}
      assert JobCallbacks.before_perform(JobWithErrorPerformCallback, args, job) == {:error, "failed"}
    end

    test "handles other return values" do
      defmodule JobWithOtherPerformCallback do
        def before_perform(_args, _job), do: %{modified: true}
      end

      args = %{test: "value"}
      job = %GoodJob.Job{id: Ecto.UUID.generate()}
      assert {:ok, result} = JobCallbacks.before_perform(JobWithOtherPerformCallback, args, job)
      assert result.modified == true
    end

    test "handles nil return" do
      defmodule JobWithNilPerformCallback do
        def before_perform(_args, _job), do: nil
      end

      args = %{test: "value"}
      job = %GoodJob.Job{id: Ecto.UUID.generate()}
      assert {:ok, result} = JobCallbacks.before_perform(JobWithNilPerformCallback, args, job)
      assert result == args
    end
  end

  describe "after_perform/4" do
    test "executes callback when defined" do
      args = %{test: "value"}
      job = %GoodJob.Job{id: Ecto.UUID.generate()}
      assert JobCallbacks.after_perform(JobWithCallbacks, args, job, :ok) == :ok
    end

    test "returns :ok when callback not defined" do
      args = %{test: "value"}
      job = %GoodJob.Job{id: Ecto.UUID.generate()}
      assert JobCallbacks.after_perform(JobWithoutCallbacks, args, job, :ok) == :ok
    end
  end

  describe "on_error/4" do
    test "executes callback when defined" do
      args = %{test: "value"}
      job = %GoodJob.Job{id: Ecto.UUID.generate()}
      error = %RuntimeError{message: "test error"}
      assert JobCallbacks.on_error(JobWithCallbacks, args, job, error) == :ok
    end

    test "returns :ok when callback not defined" do
      args = %{test: "value"}
      job = %GoodJob.Job{id: Ecto.UUID.generate()}
      error = %RuntimeError{message: "test error"}
      assert JobCallbacks.on_error(JobWithoutCallbacks, args, job, error) == :ok
    end
  end
end
