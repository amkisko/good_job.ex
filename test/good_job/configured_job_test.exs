defmodule GoodJob.ConfiguredJobTest do
  use ExUnit.Case, async: false
  use GoodJob.Testing.JobCase

  alias GoodJob.ConfiguredJob

  defmodule TestJob do
    @behaviour GoodJob.Behaviour

    def perform(_args) do
      :ok
    end
  end

  describe "new/2" do
    test "creates a configured job" do
      job = ConfiguredJob.new(TestJob, queue: "test")
      assert job.job_module == TestJob
      assert job.options == [queue: "test"]
    end

    test "normalizes wait option to scheduled_at" do
      job = ConfiguredJob.new(TestJob, wait: 300)
      assert Keyword.has_key?(job.options, :scheduled_at)
      scheduled_at = Keyword.get(job.options, :scheduled_at)
      assert %DateTime{} = scheduled_at
      assert DateTime.diff(scheduled_at, DateTime.utc_now(), :second) >= 299
    end

    test "normalizes wait_until with DateTime" do
      datetime = DateTime.add(DateTime.utc_now(), 3600, :second)
      job = ConfiguredJob.new(TestJob, wait_until: datetime)
      assert Keyword.get(job.options, :scheduled_at) == datetime
    end

    test "normalizes wait_until with NaiveDateTime" do
      naive_dt = ~N[2024-01-01 12:00:00]
      job = ConfiguredJob.new(TestJob, wait_until: naive_dt)
      scheduled_at = Keyword.get(job.options, :scheduled_at)
      assert %DateTime{} = scheduled_at
    end
  end

  describe "perform_now/2" do
    test "executes job inline" do
      job = ConfiguredJob.new(TestJob, queue: "test")
      result = ConfiguredJob.perform_now(job, %{data: "test"})
      assert match?({:ok, :ok}, result)
    end
  end

  describe "perform_later/2" do
    test "enqueues job for later" do
      job = ConfiguredJob.new(TestJob, queue: "test")
      result = ConfiguredJob.perform_later(job, %{data: "test"})
      assert match?({:ok, _}, result)
    end
  end
end
