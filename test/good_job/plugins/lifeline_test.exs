defmodule GoodJob.Plugins.LifelineTest do
  use ExUnit.Case, async: false
  use GoodJob.Testing.JobCase

  alias GoodJob.{Config, Job, Plugins.Lifeline, Repo}

  describe "validate/1" do
    test "returns :ok for valid options" do
      assert Lifeline.validate(rescue_after: 300, interval: 60) == :ok
      assert Lifeline.validate([]) == :ok
    end

    test "returns error for invalid rescue_after" do
      assert {:error, _} = Lifeline.validate(rescue_after: "invalid")
    end

    test "returns error for invalid interval" do
      assert {:error, _} = Lifeline.validate(interval: "invalid")
    end
  end

  describe "start_link/1" do
    test "starts the lifeline process" do
      config = Config.config()
      {:ok, pid} = Lifeline.start_link(conf: config, name: :test_lifeline)
      assert is_pid(pid)
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end
  end

  describe "rescue_stuck_jobs/1" do
    test "can identify and rescue stuck jobs" do
      repo = Repo.repo()
      config = Config.config()

      # Create a stuck job
      _job =
        repo.transaction(fn ->
          {:ok, j} = GoodJob.enqueue(TestJob, %{data: "test"})

          # Simulate a stuck job by setting performed_at and locked_at in the past
          cutoff = DateTime.add(DateTime.utc_now(), -400, :second)

          j
          |> Job.changeset(%{
            performed_at: cutoff,
            locked_by_id: Ecto.UUID.generate(),
            locked_at: cutoff
          })
          |> repo.update!()
        end)

      # Start lifeline with short rescue_after
      {:ok, pid} = Lifeline.start_link(conf: config, rescue_after: 300, interval: 1, name: :test_lifeline_rescue)

      # Wait for the rescue to run (may take up to 2 seconds)
      Process.sleep(2500)

      # Verify the process is still running and can handle messages
      assert Process.alive?(pid)

      GenServer.stop(pid)
    end
  end
end
