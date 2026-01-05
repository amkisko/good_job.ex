defmodule GoodJob.ExecutionModeTest do
  use ExUnit.Case, async: false

  alias GoodJob.{ExecutionMode, Job}

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(GoodJob.Repo.repo())
    :ok
  end

  describe "execute/3" do
    test "executes job in inline mode" do
      Ecto.Adapters.SQL.Sandbox.checkout(GoodJob.Repo.repo())
      repo = GoodJob.Repo.repo()

      defmodule TestWorker do
        use GoodJob.Job

        @impl GoodJob.Behaviour
        def perform(_args), do: :ok
      end

      job =
        %Job{
          id: Ecto.UUID.generate(),
          active_job_id: Ecto.UUID.generate(),
          job_class: "Elixir.GoodJob.ExecutionModeTest.TestWorker",
          serialized_params: %{"arguments" => %{}},
          queue_name: "default",
          executions_count: 0
        }
        |> Job.changeset(%{})
        |> repo.insert!()

      result = ExecutionMode.execute(job, :inline)
      assert result == {:ok, :ok}
    end

    test "returns job for async mode" do
      job = %Job{id: Ecto.UUID.generate()}
      assert ExecutionMode.execute(job, :async) == {:ok, job}
    end

    test "starts task for external mode" do
      job = %Job{
        id: Ecto.UUID.generate(),
        job_class: "Elixir.GoodJob.ExecutorTest.TestWorker",
        serialized_params: %{"arguments" => %{}},
        executions_count: 0
      }

      assert ExecutionMode.execute(job, :external) == {:ok, job}
    end

    test "raises for invalid mode" do
      job = %Job{id: Ecto.UUID.generate()}

      assert_raise ArgumentError, fn ->
        ExecutionMode.execute(job, :invalid)
      end
    end
  end
end
