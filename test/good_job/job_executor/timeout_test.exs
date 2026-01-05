defmodule GoodJob.JobExecutor.TimeoutTest do
  use ExUnit.Case, async: false

  alias GoodJob.{Errors, Job, JobExecutor.Timeout}

  defmodule JobWithTimeout do
    use GoodJob.Job, timeout: 100

    @impl GoodJob.Behaviour
    def perform(_args) do
      :ok
    end
  end

  defmodule JobWithoutTimeout do
    use GoodJob.Job

    @impl GoodJob.Behaviour
    def perform(_args) do
      :ok
    end
  end

  defmodule SlowJob do
    use GoodJob.Job, timeout: 50

    @impl GoodJob.Behaviour
    def perform(_args) do
      Process.sleep(200)
      :ok
    end
  end

  setup do
    job = %Job{
      id: Ecto.UUID.generate(),
      active_job_id: Ecto.UUID.generate(),
      job_class: "TestJob",
      serialized_params: %{"arguments" => []}
    }

    {:ok, job: job}
  end

  describe "get_job_timeout/2" do
    test "returns timeout from job module when defined", %{job: job} do
      assert Timeout.get_job_timeout(JobWithTimeout, job) == 100
    end

    test "returns :infinity when timeout not defined", %{job: job} do
      assert Timeout.get_job_timeout(JobWithoutTimeout, job) == :infinity
    end
  end

  describe "perform_with_timeout/3" do
    test "executes function successfully within timeout", %{job: job} do
      fun = fn -> :success end
      result = Timeout.perform_with_timeout(fun, job, 1000)
      assert result == :success
    end

    test "raises JobTimeoutError when function exceeds timeout", %{job: job} do
      fun = fn -> Process.sleep(200) end

      assert_raise Errors.JobTimeoutError, fn ->
        Timeout.perform_with_timeout(fun, job, 50)
      end
    end

    test "handles function that exits", %{job: job} do
      # Create a function that will cause the task to exit
      fun = fn ->
        # Spawn a process that exits, which will cause the task to exit
        spawn_link(fn -> Process.exit(self(), :kill) end)
        Process.sleep(100)
      end

      # The exit should be caught and re-raised as a RuntimeError
      assert_raise RuntimeError, ~r/Job process exited/, fn ->
        Timeout.perform_with_timeout(fun, job, 1000)
      end
    end

    test "handles function that raises exception", %{job: job} do
      fun = fn -> raise "test error" end

      # The exception is raised in the task, which gets caught and re-raised
      assert_raise RuntimeError, "test error", fn ->
        Timeout.perform_with_timeout(fun, job, 1000)
      end
    end

    test "returns result immediately when function completes quickly", %{job: job} do
      fun = fn -> :quick_result end
      result = Timeout.perform_with_timeout(fun, job, 1000)
      assert result == :quick_result
    end
  end
end
