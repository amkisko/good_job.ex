defmodule GoodJob.Web.DataLoaderTest do
  use GoodJob.Testing.JobCase, async: false

  alias GoodJob.Web.DataLoader
  alias GoodJob.Repo

  defp stamp_created_at(job, datetime) do
    job
    |> Ecto.Changeset.change(%{inserted_at: datetime})
    |> Repo.repo().update!()
  end

  defp discard(job, error) do
    job
    |> Ecto.Changeset.change(%{finished_at: DateTime.utc_now(), error: error})
    |> Repo.repo().update!()
  end

  describe "load_jobs/1" do
    test "lists jobs that share created_at across pages" do
      shared_time = ~U[2026-09-04 12:00:00.000000Z]
      first = create_job(%{job_class: "PageFirstJob"})
      second = create_job(%{job_class: "PageSecondJob"})
      stamp_created_at(first, shared_time)
      stamp_created_at(second, shared_time)

      {page_one, total} = DataLoader.load_jobs(page: 1, per_page: 1)
      {page_two, _} = DataLoader.load_jobs(page: 2, per_page: 1)

      listed_ids = Enum.map(page_one ++ page_two, & &1.id)
      assert total == 2
      assert Enum.sort(listed_ids) == Enum.sort([first.id, second.id])
    end

    test "filters discarded jobs by job class" do
      matching = discard(create_job(%{job_class: "MatchingDiscardedJob"}), "failed")
      other = discard(create_job(%{job_class: "OtherDiscardedJob"}), "failed")

      succeeded =
        create_job(%{job_class: "MatchingDiscardedJob"})
        |> Ecto.Changeset.change(%{finished_at: DateTime.utc_now(), error: nil})
        |> Repo.repo().update!()

      {jobs, _total} =
        DataLoader.load_jobs(state: "discarded", job_class: "MatchingDiscardedJob")

      ids = Enum.map(jobs, & &1.id)
      assert matching.id in ids
      refute other.id in ids
      refute succeeded.id in ids
    end
  end

  describe "load_batches/1" do
    test "lists batches that share created_at across pages" do
      shared_time = ~U[2026-09-04 12:00:00.000000Z]
      repo = Repo.repo()

      first =
        %GoodJob.BatchRecord{}
        |> GoodJob.BatchRecord.changeset(%{description: "first"})
        |> repo.insert!()

      second =
        %GoodJob.BatchRecord{}
        |> GoodJob.BatchRecord.changeset(%{description: "second"})
        |> repo.insert!()

      first
      |> Ecto.Changeset.change(%{inserted_at: shared_time})
      |> repo.update!()

      second
      |> Ecto.Changeset.change(%{inserted_at: shared_time})
      |> repo.update!()

      {page_one, total} = DataLoader.load_batches(page: 1, per_page: 1)
      {page_two, _} = DataLoader.load_batches(page: 2, per_page: 1)

      listed_ids = Enum.map(page_one ++ page_two, & &1.id)
      assert total == 2
      assert Enum.sort(listed_ids) == Enum.sort([first.id, second.id])
    end
  end
end
