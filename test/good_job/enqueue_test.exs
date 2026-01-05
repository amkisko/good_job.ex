defmodule GoodJob.EnqueueTest do
  use ExUnit.Case, async: false

  alias GoodJob.Repo

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

  describe "enqueue/3" do
    test "enqueues a job with default options" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      assert {:ok, job} = GoodJob.enqueue(TestJob, %{data: "test"})
      assert job.id != nil
    end

    test "enqueues a job with custom queue" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      assert {:ok, job} = GoodJob.enqueue(TestJob, %{data: "test"}, queue: "custom")
      assert job.queue_name == "custom"
    end

    test "enqueues a job with priority" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      assert {:ok, job} = GoodJob.enqueue(TestJob, %{data: "test"}, priority: 5)
      assert job.priority == 5
    end

    test "enqueues a job with scheduled_at" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      future = DateTime.add(DateTime.utc_now(), 3600, :second)
      assert {:ok, job} = GoodJob.enqueue(TestJob, %{data: "test"}, scheduled_at: future)
      assert job.scheduled_at != nil
    end

    test "enqueues a job with concurrency_key" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      assert {:ok, job} = GoodJob.enqueue(TestJob, %{data: "test"}, concurrency_key: "test-key")
      assert job.concurrency_key == "test-key"
    end

    test "enqueues a job with tags" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      assert {:ok, job} = GoodJob.enqueue(TestJob, %{data: "test"}, tags: ["important"])
      assert job.labels == ["important"]
    end
  end
end
