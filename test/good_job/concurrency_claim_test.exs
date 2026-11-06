defmodule GoodJob.ConcurrencyClaimTest do
  use ExUnit.Case, async: false

  import Ecto.Query

  alias GoodJob.{ConcurrencyClaim, Job, Repo}

  setup do
    _pid = Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
    Ecto.Adapters.SQL.Sandbox.mode(Repo.repo(), {:shared, self()})
    :ok
  end

  defp enqueue_job!(attrs) do
    active_job_id = attrs[:active_job_id] || Ecto.UUID.generate()

    {:ok, job} =
      Job.enqueue(
        Map.merge(
          %{
            active_job_id: active_job_id,
            job_class: "TestJob",
            queue_name: "default",
            serialized_params: %{"arguments" => []}
          },
          attrs
        )
      )

    job
  end

  describe "claim/1" do
    test "grants when under the running limit" do
      job = enqueue_job!(%{concurrency_key: "k1"})
      lock_id = Ecto.UUID.generate()

      assert ConcurrencyClaim.claim(
               key: "key:k1",
               limit: 1,
               scope: Job.with_concurrency_key("k1"),
               job_id: job.id,
               locked_by_id: lock_id
             )

      claim = Repo.repo().get_by!(ConcurrencyClaim, job_id: job.id)
      assert claim.state == ConcurrencyClaim.granted()
      assert claim.locked_by_id == lock_id
      assert claim.key == "key:k1"
    end

    test "records waiting when the limit is held by another running job" do
      holder = enqueue_job!(%{concurrency_key: "k1"})
      waiter = enqueue_job!(%{concurrency_key: "k1"})
      lock_id = Ecto.UUID.generate()

      Repo.repo().update_all(from(j in Job, where: j.id == ^holder.id),
        set: [locked_by_id: lock_id, locked_at: DateTime.utc_now(), performed_at: DateTime.utc_now()]
      )

      refute ConcurrencyClaim.claim(
               key: "key:k1",
               limit: 1,
               scope: Job.with_concurrency_key("k1"),
               job_id: waiter.id,
               locked_by_id: lock_id
             )

      claim = Repo.repo().get_by!(ConcurrencyClaim, job_id: waiter.id)
      assert claim.state == ConcurrencyClaim.waiting()
      assert is_nil(claim.locked_by_id)
    end
  end

  describe "release_job/1 and promote_next" do
    test "promotes the oldest waiting job by scheduling it now" do
      holder = enqueue_job!(%{concurrency_key: "k1"})
      waiter = enqueue_job!(%{concurrency_key: "k1", scheduled_at: DateTime.add(DateTime.utc_now(), 3600, :second)})
      lock_id = Ecto.UUID.generate()

      Repo.repo().update_all(from(j in Job, where: j.id == ^holder.id),
        set: [locked_by_id: lock_id, locked_at: DateTime.utc_now(), performed_at: DateTime.utc_now()]
      )

      assert ConcurrencyClaim.claim(
               key: "key:k1",
               limit: 1,
               scope: Job.with_concurrency_key("k1"),
               job_id: holder.id,
               locked_by_id: lock_id
             )

      refute ConcurrencyClaim.claim(
               key: "key:k1",
               limit: 1,
               scope: Job.with_concurrency_key("k1"),
               job_id: waiter.id,
               locked_by_id: nil
             )

      ConcurrencyClaim.release_job(holder.id)

      waiter = Repo.repo().get!(Job, waiter.id)
      assert DateTime.compare(waiter.scheduled_at, DateTime.utc_now()) != :gt

      claim = Repo.repo().get_by!(ConcurrencyClaim, job_id: waiter.id)
      assert claim.state == ConcurrencyClaim.promoted()
    end
  end

  describe "job_finished/1" do
    test "deletes claims when the job is finished" do
      job = enqueue_job!(%{concurrency_key: "k1"})
      lock_id = Ecto.UUID.generate()

      assert ConcurrencyClaim.claim(
               key: "label:billing",
               limit: 1,
               scope: Job.with_label("billing"),
               job_id: job.id,
               locked_by_id: lock_id
             )

      Repo.repo().update_all(from(j in Job, where: j.id == ^job.id),
        set: [finished_at: DateTime.utc_now()]
      )

      job = Repo.repo().get!(Job, job.id)
      ConcurrencyClaim.job_finished(job)

      assert Repo.repo().get_by(ConcurrencyClaim, job_id: job.id) == nil
    end
  end

  describe "label claim key" do
    test "scopes running jobs by label" do
      holder = enqueue_job!(%{labels: ["acct-1"]})
      waiter = enqueue_job!(%{labels: ["acct-1"]})
      lock_id = Ecto.UUID.generate()

      Repo.repo().update_all(from(j in Job, where: j.id == ^holder.id),
        set: [locked_by_id: lock_id, locked_at: DateTime.utc_now(), performed_at: DateTime.utc_now()]
      )

      assert ConcurrencyClaim.claim(
               key: ConcurrencyClaim.claim_key_for_label("acct-1"),
               limit: 1,
               scope: Job.with_label("acct-1"),
               job_id: holder.id,
               locked_by_id: lock_id
             )

      refute ConcurrencyClaim.claim(
               key: ConcurrencyClaim.claim_key_for_label("acct-1"),
               limit: 1,
               scope: Job.with_label("acct-1"),
               job_id: waiter.id,
               locked_by_id: nil
             )
    end
  end
end
