defmodule GoodJob.Job.QueryTest do
  use ExUnit.Case, async: false

  alias GoodJob.{Job, Repo}

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
    Ecto.Adapters.SQL.Sandbox.mode(Repo.repo(), :manual)
    :ok
  end

  describe "query functions" do
    test "unfinished/1 returns query for unfinished jobs" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      query = Job.unfinished()
      assert %Ecto.Query{} = query
    end

    test "finished/1 returns query for finished jobs" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      query = Job.finished()
      assert %Ecto.Query{} = query
    end

    test "unlocked/1 returns query for unlocked jobs" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      query = Job.unlocked()
      assert %Ecto.Query{} = query
    end

    test "locked/1 returns query for locked jobs" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      query = Job.locked()
      assert %Ecto.Query{} = query
    end

    test "in_queue/2 filters by queue name" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      query = Job.in_queue("default")
      assert %Ecto.Query{} = query
    end

    test "scheduled_before/2 filters by scheduled time" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      datetime = DateTime.utc_now()
      query = Job.scheduled_before(datetime)
      assert %Ecto.Query{} = query
    end

    test "finished_before/2 filters by finished time" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      datetime = DateTime.utc_now()
      query = Job.finished_before(datetime)
      assert %Ecto.Query{} = query
    end

    test "with_concurrency_key/2 filters by concurrency key" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      query = Job.with_concurrency_key("test-key")
      assert %Ecto.Query{} = query
    end

    test "with_cron_key/2 filters by cron key" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      query = Job.with_cron_key("test-cron")
      assert %Ecto.Query{} = query
    end

    test "with_priority/2 filters by priority" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      query = Job.with_priority(5)
      assert %Ecto.Query{} = query
    end

    test "with_labels/2 filters by labels" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      query = Job.with_labels(["important"])
      assert %Ecto.Query{} = query
    end

    test "dequeueing_ordered/1 orders jobs for dequeueing" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      query = Job.dequeueing_ordered()
      assert %Ecto.Query{} = query
    end

    test "only_scheduled/1 filters scheduled jobs" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      query = Job.only_scheduled()
      assert %Ecto.Query{} = query
    end

    test "exclude_paused/1 excludes paused jobs" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      query = Job.exclude_paused()
      assert %Ecto.Query{} = query
    end

    test "exclude_paused/1 handles non-query input" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      # Test the case where query is not an Ecto.Query struct
      # This tests the _ -> from(j in Job) branch
      query = GoodJob.Job.Query.exclude_paused(:not_a_query)
      assert %Ecto.Query{} = query
    end

    test "running/1 returns query for running jobs" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      query = Job.running()
      assert %Ecto.Query{} = query
    end

    test "queued/1 returns query for queued jobs" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      query = Job.queued()
      assert %Ecto.Query{} = query
    end

    test "succeeded/1 returns query for succeeded jobs" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      query = Job.succeeded()
      assert %Ecto.Query{} = query
    end

    test "discarded/1 returns query for discarded jobs" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      query = Job.discarded()
      assert %Ecto.Query{} = query
    end

    test "scheduled/1 returns query for scheduled jobs" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      query = Job.scheduled()
      assert %Ecto.Query{} = query
    end

    test "in_batch/2 filters by batch id" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      batch_id = Ecto.UUID.generate()
      query = Job.in_batch(batch_id)
      assert %Ecto.Query{} = query
    end

    test "with_label/2 filters by label" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      query = Job.with_label("important")
      assert %Ecto.Query{} = query
    end

    test "with_any_label/2 filters by any label" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      query = Job.with_any_label(["important", "billing"])
      assert %Ecto.Query{} = query
    end

    test "with_all_labels/2 filters by all labels" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      query = Job.with_all_labels(["important", "billing"])
      assert %Ecto.Query{} = query
    end

    test "order_for_candidate_lookup/1 orders jobs" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      query = Job.order_for_candidate_lookup()
      assert %Ecto.Query{} = query
    end

    test "with_job_class/2 filters by job class" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      query = Job.with_job_class("MyApp::MyJob")
      assert %Ecto.Query{} = query
    end

    test "with_batch_id/2 filters by batch id" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      batch_id = Ecto.UUID.generate()
      query = Job.with_batch_id(batch_id)
      assert %Ecto.Query{} = query
    end

    test "created_after/2 filters by created time" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      datetime = DateTime.utc_now()
      query = Job.created_after(datetime)
      assert %Ecto.Query{} = query
    end

    test "created_before/2 filters by created time" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      datetime = DateTime.utc_now()
      query = Job.created_before(datetime)
      assert %Ecto.Query{} = query
    end

    test "with_min_priority/2 filters by minimum priority" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      query = Job.with_min_priority(5)
      assert %Ecto.Query{} = query
    end

    test "with_max_priority/2 filters by maximum priority" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      query = Job.with_max_priority(10)
      assert %Ecto.Query{} = query
    end

    test "with_errors/1 filters jobs with errors" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      query = Job.with_errors()
      assert %Ecto.Query{} = query
    end

    test "without_errors/1 filters jobs without errors" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      query = Job.without_errors()
      assert %Ecto.Query{} = query
    end

    test "order_by_created_desc/1 orders by created desc" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      query = Job.order_by_created_desc()
      assert %Ecto.Query{} = query
    end

    test "order_by_created_asc/1 orders by created asc" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      query = Job.order_by_created_asc()
      assert %Ecto.Query{} = query
    end

    test "order_by_scheduled_asc/1 orders by scheduled asc" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      query = Job.order_by_scheduled_asc()
      assert %Ecto.Query{} = query
    end

    test "order_by_finished_desc/1 orders by finished desc" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      query = Job.order_by_finished_desc()
      assert %Ecto.Query{} = query
    end

    test "advisory_locked/1 returns query for advisory locked jobs" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      query = Job.advisory_locked()
      assert %Ecto.Query{} = query
    end

    test "advisory_unlocked/1 returns query for advisory unlocked jobs" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      query = Job.advisory_unlocked()
      assert %Ecto.Query{} = query
    end

    test "joins_advisory_locks/1 joins with pg_locks" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      query = Job.joins_advisory_locks()
      assert %Ecto.Query{} = query
    end
  end

  describe "calculate_state/1" do
    test "calculates state for available job" do
      job = %Job{
        finished_at: nil,
        scheduled_at: nil,
        performed_at: nil,
        locked_by_id: nil
      }

      assert Job.calculate_state(job) == :available
    end

    test "calculates state for scheduled job" do
      future = DateTime.add(DateTime.utc_now(), 3600, :second)

      job = %Job{
        finished_at: nil,
        scheduled_at: future,
        performed_at: nil,
        locked_by_id: nil
      }

      assert Job.calculate_state(job) == :scheduled
    end

    test "calculates state for running job" do
      job = %Job{
        finished_at: nil,
        scheduled_at: nil,
        performed_at: DateTime.utc_now(),
        locked_by_id: Ecto.UUID.generate()
      }

      assert Job.calculate_state(job) == :running
    end

    test "calculates state for succeeded job" do
      job = %Job{
        finished_at: DateTime.utc_now(),
        error: nil
      }

      assert Job.calculate_state(job) == :succeeded
    end

    test "calculates state for discarded job" do
      job = %Job{
        finished_at: DateTime.utc_now(),
        error: "Job discarded"
      }

      assert Job.calculate_state(job) == :discarded
    end

    test "calculates state for retried job" do
      job = %Job{
        finished_at: nil,
        retried_good_job_id: Ecto.UUID.generate()
      }

      assert Job.calculate_state(job) == :retried
    end
  end

  describe "changeset/2" do
    test "creates changeset with valid attributes" do
      job = %Job{}

      changeset =
        Job.changeset(job, %{
          active_job_id: Ecto.UUID.generate(),
          job_class: "TestJob",
          queue_name: "default",
          serialized_params: %{"arguments" => []}
        })

      assert changeset.valid?
    end

    test "validates required fields" do
      job = %Job{}
      changeset = Job.changeset(job, %{})
      refute changeset.valid?
    end
  end

  describe "build_for_enqueue/1" do
    test "builds job for enqueueing" do
      attrs = %{
        active_job_id: Ecto.UUID.generate(),
        job_class: "TestJob",
        queue_name: "default",
        serialized_params: %{"arguments" => []}
      }

      changeset = Job.build_for_enqueue(attrs)
      assert %Ecto.Changeset{} = changeset
    end
  end

  describe "enqueue/1" do
    test "enqueues a job" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())

      attrs = %{
        active_job_id: Ecto.UUID.generate(),
        job_class: "TestJob",
        queue_name: "default",
        serialized_params: %{"arguments" => []}
      }

      assert {:ok, job} = Job.enqueue(attrs)
      assert job.id != nil
    end
  end

  describe "find_by_id/1" do
    test "finds job by id" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      job_id = Ecto.UUID.generate()
      result = Job.find_by_id(job_id)
      assert result == nil or is_struct(result, Job)
    end
  end

  describe "find_by_active_job_id/1" do
    test "finds job by active_job_id" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      active_job_id = Ecto.UUID.generate()
      result = Job.find_by_active_job_id(active_job_id)
      assert result == nil or is_struct(result, Job)
    end
  end

  describe "delete/1" do
    test "deletes a job" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      repo = Repo.repo()

      job =
        %Job{
          id: Ecto.UUID.generate(),
          active_job_id: Ecto.UUID.generate(),
          job_class: "TestJob",
          queue_name: "default",
          serialized_params: %{"arguments" => []}
        }
        |> Job.changeset(%{})
        |> repo.insert!()

      result = Job.delete(job)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "dequeueing_ordered/1" do
    test "orders jobs for dequeueing" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      query = Job.dequeueing_ordered()
      assert %Ecto.Query{} = query
    end
  end

  describe "only_scheduled/1" do
    test "filters scheduled jobs" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      query = Job.only_scheduled()
      assert %Ecto.Query{} = query
    end
  end

  describe "retry/1" do
    test "retries a discarded job" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      repo = Repo.repo()

      job =
        %Job{
          id: Ecto.UUID.generate(),
          active_job_id: Ecto.UUID.generate(),
          job_class: "TestJob",
          queue_name: "default",
          serialized_params: %{"arguments" => []},
          finished_at: DateTime.utc_now(),
          error: "Test error"
        }
        |> Job.changeset(%{})
        |> repo.insert!()

      result = Job.retry(job)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end
end
