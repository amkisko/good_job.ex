defmodule GoodJob.TestingTest do
  use GoodJob.Testing.JobCase

  alias GoodJob.{Job, Testing}

  defmodule TestJob do
    use GoodJob.Job

    @impl GoodJob.Behaviour
    def perform(args) do
      # Handle both array-wrapped (ActiveJob format) and direct map arguments
      args = if is_list(args) and length(args) == 1, do: List.first(args), else: args
      # Handle both atom and string keys from serialization
      _data = Map.get(args, :data) || Map.get(args, "data")
      :ok
    end
  end

  describe "assert_enqueued/3" do
    test "asserts job was enqueued" do
      TestJob.enqueue(%{data: "test"})

      job = Testing.assert_enqueued(TestJob, %{data: "test"})
      assert job != nil
      assert job.job_class == "Elixir.GoodJob.TestingTest.TestJob"
    end

    test "asserts job was enqueued with queue option" do
      TestJob.enqueue(%{data: "test"}, queue: "high_priority")

      job = Testing.assert_enqueued(TestJob, %{data: "test"}, queue: "high_priority")
      assert job.queue_name == "high_priority"
    end

    test "fails when job not enqueued" do
      assert_raise ExUnit.AssertionError, fn ->
        Testing.assert_enqueued(TestJob, %{data: "nonexistent"})
      end
    end
  end

  describe "assert_performed/1" do
    test "asserts job was performed" do
      {:ok, job} = TestJob.enqueue(%{data: "test"})

      # Execute the job
      GoodJob.JobExecutor.execute_inline(job)

      # Assert it was performed
      Testing.assert_performed(job)
    end

    test "fails when job not performed" do
      {:ok, job} = TestJob.enqueue(%{data: "test"})

      assert_raise ExUnit.AssertionError, fn ->
        Testing.assert_performed(job)
      end
    end
  end

  describe "refute_enqueued/3" do
    test "passes when job not enqueued" do
      assert Testing.refute_enqueued(TestJob, %{data: "nonexistent"}) == :ok
    end

    test "fails when job was enqueued" do
      TestJob.enqueue(%{data: "test"})

      assert_raise ExUnit.AssertionError, fn ->
        Testing.refute_enqueued(TestJob, %{data: "test"})
      end
    end
  end

  describe "perform_jobs/1" do
    test "performs all available jobs" do
      TestJob.enqueue(%{data: "test1"})
      TestJob.enqueue(%{data: "test2"})

      count = Testing.perform_jobs()
      assert count == 2

      # Verify jobs were performed
      jobs = Repo.repo().all(Job)
      assert Enum.all?(jobs, &(Job.calculate_state(&1) == :succeeded))
    end

    test "performs jobs for specific module" do
      defmodule OtherJob do
        use GoodJob.Job

        @impl GoodJob.Behaviour
        def perform(_args) do
          :ok
        end
      end

      TestJob.enqueue(%{data: "test1"})
      OtherJob.enqueue(%{data: "test2"})

      count = Testing.perform_jobs(TestJob)
      assert count == 1

      # Verify only TestJob was performed
      test_job = Repo.repo().one(from(j in Job, where: j.job_class == "Elixir.GoodJob.TestingTest.TestJob"))
      assert Job.calculate_state(test_job) == :succeeded

      other_job = Repo.repo().one(from(j in Job, where: j.job_class == "Elixir.GoodJob.TestingTest.OtherJob"))
      assert Job.calculate_state(other_job) == :available
    end
  end
end
