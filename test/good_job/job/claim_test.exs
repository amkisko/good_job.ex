defmodule GoodJob.Job.ClaimTest do
  use GoodJob.Testing.RepoCase, async: false

  alias GoodJob.{Job, JobPerformer, Repo}

  setup do
    original = Application.get_env(:good_job, :config, %{})

    on_exit(fn ->
      Application.put_env(:good_job, :config, original)
    end)

    :ok
  end

  for strategy <- [:skiplocked, :hybrid] do
    test "claim_next with #{strategy} accepts string UUID lock_id and returns locked job" do
      strategy = unquote(strategy)

      Application.put_env(
        :good_job,
        :config,
        Map.merge(Map.new(Application.get_env(:good_job, :config, %{})), %{
          lock_strategy: strategy,
          repo: Repo.repo()
        })
      )

      {:ok, job} = insert_job()

      lock_id = Ecto.UUID.generate()
      parsed = JobPerformer.parse_queues("*")

      claimed = Job.Claim.claim_next(Repo.repo(), parsed, lock_id, strategy, [])

      assert %Job{id: id, locked_by_id: locked_by_id} = claimed
      assert id == job.id
      assert locked_by_id == lock_id
    end

    test "claim_many with #{strategy} claims multiple unlocked jobs in one call" do
      strategy = unquote(strategy)

      Application.put_env(
        :good_job,
        :config,
        Map.merge(Map.new(Application.get_env(:good_job, :config, %{})), %{
          lock_strategy: strategy,
          repo: Repo.repo()
        })
      )

      {:ok, job1} = insert_job(%{queue_name: "batch"})
      {:ok, job2} = insert_job(%{queue_name: "batch"})
      {:ok, job3} = insert_job(%{queue_name: "batch"})

      lock_id = Ecto.UUID.generate()
      parsed = JobPerformer.parse_queues("batch")

      claimed = Job.Claim.claim_many(Repo.repo(), parsed, lock_id, strategy, 2, [])

      assert length(claimed) == 2
      assert Enum.all?(claimed, &(&1.locked_by_id == lock_id))

      claimed_ids = MapSet.new(Enum.map(claimed, & &1.id))
      assert MapSet.size(claimed_ids) == 2
      assert MapSet.subset?(claimed_ids, MapSet.new([job1.id, job2.id, job3.id]))
    end
  end

  defp insert_job(attrs \\ %{}) do
    defaults = %{
      active_job_id: Ecto.UUID.generate(),
      job_class: "Elixir.GoodJob.Testing.Helpers.TestJob",
      queue_name: "default",
      priority: 0,
      serialized_params: %{"job_class" => "Elixir.GoodJob.Testing.Helpers.TestJob", "arguments" => [%{}]},
      scheduled_at: DateTime.utc_now()
    }

    %Job{}
    |> Job.changeset(Map.merge(defaults, attrs))
    |> Repo.repo().insert()
  end
end
