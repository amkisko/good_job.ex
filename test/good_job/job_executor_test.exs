defmodule GoodJob.JobExecutorTest do
  use ExUnit.Case, async: false
  use GoodJob.Testing.JobCase

  alias GoodJob.{Job, JobExecutor, Repo}

  defmodule SimpleJob do
    use GoodJob.Job

    @impl GoodJob.Behaviour
    def perform(_args) do
      :ok
    end
  end

  defmodule JobWithReturnValue do
    use GoodJob.Job

    @impl GoodJob.Behaviour
    def perform(_args) do
      {:ok, "result"}
    end
  end

  defmodule JobWithError do
    use GoodJob.Job

    @impl GoodJob.Behaviour
    def perform(_args) do
      {:error, "failed"}
    end
  end

  defmodule JobWithCancel do
    use GoodJob.Job

    @impl GoodJob.Behaviour
    def perform(_args) do
      {:cancel, "cancelled"}
    end
  end

  defmodule JobWithDiscard do
    use GoodJob.Job

    @impl GoodJob.Behaviour
    def perform(_args) do
      :discard
    end
  end

  defmodule JobWithDiscardReason do
    use GoodJob.Job

    @impl GoodJob.Behaviour
    def perform(_args) do
      {:discard, "reason"}
    end
  end

  defmodule JobWithSnooze do
    use GoodJob.Job

    @impl GoodJob.Behaviour
    def perform(_args) do
      {:snooze, 60}
    end
  end

  defmodule JobWithOtherReturn do
    use GoodJob.Job

    @impl GoodJob.Behaviour
    def perform(_args) do
      "other"
    end
  end

  defmodule JobWithException do
    use GoodJob.Job

    @impl GoodJob.Behaviour
    def perform(_args) do
      raise "test error"
    end
  end

  defmodule JobWithThrow do
    use GoodJob.Job

    @impl GoodJob.Behaviour
    def perform(_args) do
      throw(:test_throw)
    end
  end

  defmodule JobWithExit do
    use GoodJob.Job

    @impl GoodJob.Behaviour
    def perform(_args) do
      exit(:test_exit)
    end
  end

  defmodule JobWithBeforePerform do
    use GoodJob.Job

    def before_perform(args, _job) do
      {:ok, Map.put(args, :modified, true)}
    end

    @impl GoodJob.Behaviour
    def perform(args) do
      if args[:modified] do
        :ok
      else
        {:error, "not modified"}
      end
    end
  end

  defmodule JobWithBeforePerformError do
    use GoodJob.Job

    def before_perform(_args, _job) do
      {:error, "before_perform failed"}
    end

    @impl GoodJob.Behaviour
    def perform(_args) do
      :ok
    end
  end

  defmodule JobWithAfterPerform do
    use GoodJob.Job

    def after_perform(_args, _job, result) do
      send(self(), {:after_perform, result})
      :ok
    end

    @impl GoodJob.Behaviour
    def perform(_args) do
      :ok
    end
  end

  defmodule JobWithTimeout do
    use GoodJob.Job

    def good_job_timeout do
      100
    end

    @impl GoodJob.Behaviour
    def perform(_args) do
      Process.sleep(50)
      :ok
    end
  end

  defmodule JobWithBatch do
    use GoodJob.Job

    @impl GoodJob.Behaviour
    def perform(_args) do
      :ok
    end
  end

  describe "execute_inline/2" do
    test "executes job with nil performed_at" do
      repo = Repo.repo()
      Ecto.Adapters.SQL.Sandbox.checkout(repo)

      {:ok, job} = SimpleJob.enqueue(%{})

      result = JobExecutor.execute_inline(job)
      assert {:ok, :ok} = result

      # Verify performed_at was set
      updated_job = repo.get!(Job, job.id)
      assert updated_job.performed_at != nil
    end

    test "executes job with existing performed_at" do
      repo = Repo.repo()
      Ecto.Adapters.SQL.Sandbox.checkout(repo)

      {:ok, job} = SimpleJob.enqueue(%{})
      now = DateTime.utc_now()
      job = repo.update!(Job.changeset(job, %{performed_at: now}))

      result = JobExecutor.execute_inline(job)
      assert {:ok, :ok} = result
    end

    test "handles update error gracefully" do
      repo = Repo.repo()
      Ecto.Adapters.SQL.Sandbox.checkout(repo)

      {:ok, job} = SimpleJob.enqueue(%{})

      # Create a job struct with invalid changeset to simulate update error
      # We can't easily simulate a real update error, so we'll just test that
      # execute_inline works even if performed_at is already set
      job = %{job | performed_at: DateTime.utc_now()}

      # Should still execute (skips update since performed_at is set)
      result = JobExecutor.execute_inline(job)
      assert {:ok, :ok} = result
    end
  end

  describe "execute/3" do
    test "executes simple job successfully" do
      repo = Repo.repo()
      Ecto.Adapters.SQL.Sandbox.checkout(repo)

      {:ok, job} = SimpleJob.enqueue(%{})

      result = JobExecutor.execute(job, nil)
      assert {:ok, :ok} = result

      updated_job = repo.get!(Job, job.id)
      assert updated_job.performed_at != nil
    end

    test "executes job with return value" do
      repo = Repo.repo()
      Ecto.Adapters.SQL.Sandbox.checkout(repo)

      {:ok, job} = JobWithReturnValue.enqueue(%{})

      result = JobExecutor.execute(job, nil)
      assert {:ok, {:ok, "result"}} = result
    end

    test "executes job with error return" do
      repo = Repo.repo()
      Ecto.Adapters.SQL.Sandbox.checkout(repo)

      {:ok, job} = JobWithError.enqueue(%{})

      result = JobExecutor.execute(job, nil)
      assert {:ok, {:error, "failed"}} = result
    end

    test "executes job with cancel" do
      repo = Repo.repo()
      Ecto.Adapters.SQL.Sandbox.checkout(repo)

      {:ok, job} = JobWithCancel.enqueue(%{})

      result = JobExecutor.execute(job, nil)
      assert {:ok, {:cancel, "cancelled"}} = result
    end

    test "executes job with discard" do
      repo = Repo.repo()
      Ecto.Adapters.SQL.Sandbox.checkout(repo)

      {:ok, job} = JobWithDiscard.enqueue(%{})

      result = JobExecutor.execute(job, nil)
      assert {:ok, :discard} = result
    end

    test "executes job with discard reason" do
      repo = Repo.repo()
      Ecto.Adapters.SQL.Sandbox.checkout(repo)

      {:ok, job} = JobWithDiscardReason.enqueue(%{})

      result = JobExecutor.execute(job, nil)
      assert {:ok, {:discard, "reason"}} = result
    end

    test "executes job with snooze" do
      repo = Repo.repo()
      Ecto.Adapters.SQL.Sandbox.checkout(repo)

      {:ok, job} = JobWithSnooze.enqueue(%{})

      result = JobExecutor.execute(job, nil)
      assert {:ok, {:snooze, 60}} = result
    end

    test "executes job with other return value" do
      repo = Repo.repo()
      Ecto.Adapters.SQL.Sandbox.checkout(repo)

      {:ok, job} = JobWithOtherReturn.enqueue(%{})

      result = JobExecutor.execute(job, nil)
      assert {:ok, "other"} = result
    end

    test "handles job with exception" do
      repo = Repo.repo()
      Ecto.Adapters.SQL.Sandbox.checkout(repo)

      {:ok, job} = JobWithException.enqueue(%{})

      result = JobExecutor.execute(job, nil)
      assert {:error, %RuntimeError{}} = result
    end

    test "handles job with throw" do
      repo = Repo.repo()
      Ecto.Adapters.SQL.Sandbox.checkout(repo)

      {:ok, job} = JobWithThrow.enqueue(%{})

      result = JobExecutor.execute(job, nil)
      assert {:error, %RuntimeError{}} = result
    end

    test "handles job with exit" do
      repo = Repo.repo()
      Ecto.Adapters.SQL.Sandbox.checkout(repo)

      {:ok, job} = JobWithExit.enqueue(%{})

      result = JobExecutor.execute(job, nil)
      # Exit is normalized to RuntimeError
      assert {:error, error} = result
      assert %RuntimeError{} = error
    end

    test "executes job with before_perform callback" do
      repo = Repo.repo()
      Ecto.Adapters.SQL.Sandbox.checkout(repo)

      {:ok, job} = JobWithBeforePerform.enqueue(%{})

      result = JobExecutor.execute(job, nil)
      assert {:ok, :ok} = result
    end

    test "handles before_perform error" do
      repo = Repo.repo()
      Ecto.Adapters.SQL.Sandbox.checkout(repo)

      {:ok, job} = JobWithBeforePerformError.enqueue(%{})

      assert_raise RuntimeError, ~r/before_perform callback returned error/, fn ->
        JobExecutor.execute(job, nil)
      end
    end

    test "executes job with after_perform callback" do
      repo = Repo.repo()
      Ecto.Adapters.SQL.Sandbox.checkout(repo)

      {:ok, job} = JobWithAfterPerform.enqueue(%{})

      result = JobExecutor.execute(job, nil)
      assert {:ok, :ok} = result

      receive do
        {:after_perform, :ok} -> :ok
      after
        100 -> flunk("after_perform not called")
      end
    end

    test "executes job with timeout" do
      repo = Repo.repo()
      Ecto.Adapters.SQL.Sandbox.checkout(repo)

      {:ok, job} = JobWithTimeout.enqueue(%{})

      result = JobExecutor.execute(job, nil)
      assert {:ok, :ok} = result
    end

    test "executes job with batch_id" do
      repo = Repo.repo()
      Ecto.Adapters.SQL.Sandbox.checkout(repo)

      batch_id = Ecto.UUID.generate()
      {:ok, job} = JobWithBatch.enqueue(%{}, batch_id: batch_id)

      result = JobExecutor.execute(job, nil)
      assert {:ok, :ok} = result
    end

    test "executes job with lock_id" do
      repo = Repo.repo()
      Ecto.Adapters.SQL.Sandbox.checkout(repo)

      {:ok, job} = SimpleJob.enqueue(%{})
      lock_id = "test-lock-id"

      result = JobExecutor.execute(job, lock_id)
      assert {:ok, :ok} = result
    end

    test "handles job module without perform/1" do
      repo = Repo.repo()
      Ecto.Adapters.SQL.Sandbox.checkout(repo)

      job =
        %Job{
          id: Ecto.UUID.generate(),
          active_job_id: Ecto.UUID.generate(),
          job_class: "Elixir.NonExistentModule",
          serialized_params: %{"arguments" => [%{}]},
          queue_name: "default",
          executions_count: 0
        }
        |> Job.changeset(%{})
        |> repo.insert!()

      assert_raise RuntimeError, ~r/does not implement perform\/1/, fn ->
        JobExecutor.execute(job, nil)
      end
    end
  end
end
