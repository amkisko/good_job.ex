defmodule GoodJob.Engines.InlineTest do
  use ExUnit.Case, async: false

  alias GoodJob.{Engines.Inline, Job, Repo}

  defmodule TestJob do
    use GoodJob.Job

    @impl GoodJob.Behaviour
    def perform(_args) do
      :ok
    end
  end

  defmodule FailingJob do
    use GoodJob.Job

    @impl GoodJob.Behaviour
    def perform(_args) do
      {:error, "failed"}
    end
  end

  defmodule CancelledJob do
    use GoodJob.Job

    @impl GoodJob.Behaviour
    def perform(_args) do
      {:cancel, "cancelled"}
    end
  end

  defmodule DiscardedJob do
    use GoodJob.Job

    @impl GoodJob.Behaviour
    def perform(_args) do
      :discard
    end
  end

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
    Ecto.Adapters.SQL.Sandbox.mode(Repo.repo(), :manual)
    :ok
  end

  describe "insert_job/3" do
    test "inserts and executes job successfully" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      config = GoodJob.Config.config()

      job = %Job{
        id: Ecto.UUID.generate(),
        active_job_id: Ecto.UUID.generate(),
        job_class: "Elixir.GoodJob.Engines.InlineTest.TestJob",
        serialized_params: %{"arguments" => [%{}]},
        executions_count: 0
      }

      changeset = Job.changeset(job, %{})
      assert {:ok, _job} = Inline.insert_job(config, changeset, [])
    end

    test "handles job execution failure" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      config = GoodJob.Config.config()

      job = %Job{
        id: Ecto.UUID.generate(),
        active_job_id: Ecto.UUID.generate(),
        job_class: "Elixir.GoodJob.Engines.InlineTest.FailingJob",
        serialized_params: %{"arguments" => [%{}]},
        executions_count: 0
      }

      changeset = Job.changeset(job, %{})
      assert {:ok, _job} = Inline.insert_job(config, changeset, [])
    end

    test "handles cancelled job" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      config = GoodJob.Config.config()

      job = %Job{
        id: Ecto.UUID.generate(),
        active_job_id: Ecto.UUID.generate(),
        job_class: "Elixir.GoodJob.Engines.InlineTest.CancelledJob",
        serialized_params: %{"arguments" => [%{}]},
        executions_count: 0
      }

      changeset = Job.changeset(job, %{})
      assert {:ok, _job} = Inline.insert_job(config, changeset, [])
    end

    test "handles discarded job" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      config = GoodJob.Config.config()

      job = %Job{
        id: Ecto.UUID.generate(),
        active_job_id: Ecto.UUID.generate(),
        job_class: "Elixir.GoodJob.Engines.InlineTest.DiscardedJob",
        serialized_params: %{"arguments" => [%{}]},
        executions_count: 0
      }

      changeset = Job.changeset(job, %{})
      assert {:ok, _job} = Inline.insert_job(config, changeset, [])
    end

    test "handles invalid changeset" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      config = GoodJob.Config.config()
      changeset = Job.changeset(%Job{}, %{})
      # This will fail validation
      result = Inline.insert_job(config, changeset, [])
      assert match?({:error, _}, result)
    end

    test "updates job with success state" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      config = GoodJob.Config.config()

      job = %Job{
        id: Ecto.UUID.generate(),
        active_job_id: Ecto.UUID.generate(),
        job_class: "Elixir.GoodJob.Engines.InlineTest.TestJob",
        serialized_params: %{"arguments" => [%{}]},
        executions_count: 0
      }

      changeset = Job.changeset(job, %{})
      {:ok, updated_job} = Inline.insert_job(config, changeset, [])

      # Verify job was updated with success state
      fresh_job = Repo.repo().get!(Job, updated_job.id)
      # For success state, finished_at should be set (performed_at may or may not be set)
      assert not is_nil(fresh_job.finished_at)
      assert is_nil(fresh_job.error)
    end

    test "updates job with failure state" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      config = GoodJob.Config.config()

      job = %Job{
        id: Ecto.UUID.generate(),
        active_job_id: Ecto.UUID.generate(),
        job_class: "Elixir.GoodJob.Engines.InlineTest.FailingJob",
        serialized_params: %{"arguments" => [%{}]},
        executions_count: 0
      }

      changeset = Job.changeset(job, %{})
      {:ok, updated_job} = Inline.insert_job(config, changeset, [])

      # Verify job was updated with failure state
      # Reload from database to ensure we have the latest state
      fresh_job = Repo.repo().get!(Job, updated_job.id)
      # For failure state, finished_at and error should be set
      assert not is_nil(fresh_job.finished_at), "finished_at should be set for failure state"
      assert not is_nil(fresh_job.error), "error should be set for failure state"
      assert fresh_job.executions_count >= 1
    end

    test "updates job with cancelled state" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      config = GoodJob.Config.config()

      job = %Job{
        id: Ecto.UUID.generate(),
        active_job_id: Ecto.UUID.generate(),
        job_class: "Elixir.GoodJob.Engines.InlineTest.CancelledJob",
        serialized_params: %{"arguments" => [%{}]},
        executions_count: 0
      }

      changeset = Job.changeset(job, %{})
      {:ok, updated_job} = Inline.insert_job(config, changeset, [])

      # Verify job was updated with cancelled state
      fresh_job = Repo.repo().get!(Job, updated_job.id)
      assert not is_nil(fresh_job.finished_at)
      assert fresh_job.error == "Job cancelled"
    end

    test "updates job with discarded state" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      config = GoodJob.Config.config()

      job = %Job{
        id: Ecto.UUID.generate(),
        active_job_id: Ecto.UUID.generate(),
        job_class: "Elixir.GoodJob.Engines.InlineTest.DiscardedJob",
        serialized_params: %{"arguments" => [%{}]},
        executions_count: 0
      }

      changeset = Job.changeset(job, %{})
      {:ok, updated_job} = Inline.insert_job(config, changeset, [])

      # Verify job was updated with discarded state
      fresh_job = Repo.repo().get!(Job, updated_job.id)
      assert not is_nil(fresh_job.finished_at)
      assert fresh_job.error == "Job discarded"
    end

    test "handles unknown execution state" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      config = GoodJob.Config.config()

      defmodule UnknownStateJob do
        use GoodJob.Job

        @impl GoodJob.Behaviour
        def perform(_args) do
          :unknown_state
        end
      end

      job = %Job{
        id: Ecto.UUID.generate(),
        active_job_id: Ecto.UUID.generate(),
        job_class: "Elixir.GoodJob.Engines.InlineTest.UnknownStateJob",
        serialized_params: %{"arguments" => [%{}]},
        executions_count: 0
      }

      changeset = Job.changeset(job, %{})
      {:ok, _updated_job} = Inline.insert_job(config, changeset, [])
    end
  end
end
