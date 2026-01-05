defmodule GoodJob.JobExecutionIntegrationTest do
  use GoodJob.Testing.JobCase

  alias GoodJob.{Job, Repo}

  defmodule TestJob do
    use GoodJob.Job

    @impl GoodJob.Behaviour
    def perform(args) do
      # Handle both atom and string keys from serialization
      # Args can be a map directly or wrapped in an array
      data =
        case args do
          [arg_map] when is_map(arg_map) ->
            Map.get(arg_map, :data) || Map.get(arg_map, "data")

          arg_map when is_map(arg_map) ->
            Map.get(arg_map, :data) || Map.get(arg_map, "data")

          _ ->
            nil
        end

      if data do
        send(self(), {:performed, data})
      end

      :ok
    end
  end

  describe "full job lifecycle" do
    test "enqueues and executes job" do
      {:ok, job} = TestJob.enqueue(%{data: "test"})

      assert Job.calculate_state(job) == :available
      assert job.queue_name == "default"

      # Execute inline
      GoodJob.JobExecutor.execute_inline(job)

      # Verify job was executed
      job = Repo.repo().get!(Job, job.id)
      assert Job.calculate_state(job) == :succeeded
      assert not is_nil(job.performed_at)
      assert not is_nil(job.finished_at)
    end

    test "handles job errors and retries" do
      defmodule FailingJob do
        use GoodJob.Job, max_attempts: 3

        @impl GoodJob.Behaviour
        def perform(_args) do
          {:error, "failed"}
        end
      end

      {:ok, job} = FailingJob.enqueue(%{data: "test"})

      # Execute and expect error
      # execute_inline returns {:ok, job_result}, so {:error, reason} becomes {:ok, {:error, reason}}
      result = GoodJob.JobExecutor.execute_inline(job)

      # The result should be {:ok, {:error, _}}
      assert match?({:ok, {:error, _}}, result)

      # Verify job is retryable (scheduled for retry)
      # Reload job to get latest state
      job = Repo.repo().get!(Job, job.id)

      # Check if job was retried or discarded
      # If executions_count < max_attempts, it should be retried (scheduled)
      # If executions_count >= max_attempts, it should be discarded
      if job.executions_count < 3 do
        # Job should be scheduled for retry
        state = Job.calculate_state(job)

        assert state in [:queued, :scheduled, :available],
               "Expected job to be retryable, got state: #{state}, finished_at: #{inspect(job.finished_at)}, error: #{inspect(job.error)}"

        assert job.executions_count == 1
        assert not is_nil(job.scheduled_at)
      else
        # Job exhausted attempts, should be discarded
        state = Job.calculate_state(job)
        assert state == :discarded
        assert job.executions_count >= 3
      end
    end

    test "discards job after max attempts" do
      defmodule MaxAttemptsJob do
        use GoodJob.Job, max_attempts: 2

        @impl GoodJob.Behaviour
        def perform(_args) do
          {:error, "failed"}
        end
      end

      {:ok, job} = MaxAttemptsJob.enqueue(%{data: "test"})

      # Execute twice to exhaust attempts
      GoodJob.JobExecutor.execute_inline(job)
      job = Repo.repo().get!(Job, job.id)
      job = %{job | executions_count: 1}

      GoodJob.JobExecutor.execute_inline(job)

      # Verify job is discarded
      job = Repo.repo().get!(Job, job.id)
      assert Job.calculate_state(job) == :discarded
    end
  end
end
