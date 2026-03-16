defmodule GoodJob.BulkTest do
  use ExUnit.Case, async: false
  use GoodJob.Testing.JobCase

  alias GoodJob.{Bulk, Job}

  defmodule BulkJob do
    use GoodJob.Job

    @impl GoodJob.Behaviour
    def perform(_args), do: :ok
  end

  describe "capture/1" do
    test "captures jobs without inserting rows" do
      class_name = Atom.to_string(BulkJob)

      before_count =
        GoodJob.Repo.repo().aggregate(from(j in Job, where: j.job_class == ^class_name), :count, :id)

      entries =
        Bulk.capture(fn ->
          assert {:ok, :buffered} = BulkJob.perform_later(%{value: 1})
          assert {:ok, :buffered} = BulkJob.perform_later(%{value: 2})
        end)

      after_count =
        GoodJob.Repo.repo().aggregate(from(j in Job, where: j.job_class == ^class_name), :count, :id)

      assert length(entries) == 2
      assert before_count == after_count
    end
  end

  describe "enqueue/1 with block" do
    test "inserts all captured jobs in one transaction" do
      class_name = Atom.to_string(BulkJob)

      before_count =
        GoodJob.Repo.repo().aggregate(from(j in Job, where: j.job_class == ^class_name), :count, :id)

      {:ok, jobs} =
        Bulk.enqueue(fn ->
          assert {:ok, :buffered} = BulkJob.perform_later(%{value: 10})
          assert {:ok, :buffered} = BulkJob.perform_later(%{value: 20})
        end)

      after_count =
        GoodJob.Repo.repo().aggregate(from(j in Job, where: j.job_class == ^class_name), :count, :id)

      assert length(jobs) == 2
      assert Enum.all?(jobs, &match?(%Job{id: id} when is_binary(id), &1))
      assert after_count == before_count + 2
    end
  end

  describe "enqueue/1 with instances" do
    test "enqueues job instances atomically" do
      instances = [
        BulkJob.new(%{instance: 1}),
        BulkJob.new(%{instance: 2}, queue: "bulk_queue")
      ]

      {:ok, jobs} = Bulk.enqueue(instances)

      assert length(jobs) == 2
      assert Enum.any?(jobs, &(&1.queue_name == "default"))
      assert Enum.any?(jobs, &(&1.queue_name == "bulk_queue"))
    end
  end
end
