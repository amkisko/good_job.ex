# Test script for cross-language concurrency control in Elixir
# This verifies that Elixir workers respect concurrency limits set by Ruby

alias GoodJob.{Job, Repo}
import Ecto.Query

IO.puts("Testing Cross-Language Concurrency Control (Elixir)")
IO.puts(String.duplicate("=", 60))

# Test 1: Check that concurrency_key is extracted from Ruby-enqueued jobs
IO.puts("\nTest 1: Checking concurrency_key extraction")
IO.puts(String.duplicate("-", 60))

# Find a job enqueued by Ruby with concurrency_key
repo = Repo.repo()

jobs_with_key =
  repo.all(
    from(j in Job,
      where: not is_nil(j.concurrency_key) and j.queue_name == "ex.default",
      limit: 5,
      order_by: [desc: j.inserted_at]
    )
  )

if Enum.empty?(jobs_with_key) do
  IO.puts("No jobs with concurrency_key found. Enqueue some jobs from Ruby first.")
else
  IO.puts("Found #{length(jobs_with_key)} jobs with concurrency_key:")
  Enum.each(jobs_with_key, fn job ->
    IO.puts("  - Job ID: #{job.active_job_id}")
    IO.puts("    Concurrency key: #{job.concurrency_key}")
    IO.puts("    Queue: #{job.queue_name}")
    IO.puts("    State: #{if job.finished_at, do: "finished", else: if(job.locked_by_id, do: "performing", else: "enqueued")}")
  end)
end

# Test 2: Count concurrent jobs by concurrency_key
IO.puts("\nTest 2: Counting concurrent jobs by concurrency_key")
IO.puts(String.duplicate("-", 60))

if not Enum.empty?(jobs_with_key) do
  # Group by concurrency_key
  grouped =
    jobs_with_key
    |> Enum.group_by(& &1.concurrency_key)

  Enum.each(grouped, fn {key, jobs} ->
    unfinished = Enum.filter(jobs, &is_nil(&1.finished_at))
    performing = Enum.filter(unfinished, &not is_nil(&1.locked_by_id))
    enqueued = Enum.filter(unfinished, &is_nil(&1.locked_by_id))

    IO.puts("\nConcurrency key: #{key}")
    IO.puts("  - Total jobs: #{length(jobs)}")
    IO.puts("  - Unfinished: #{length(unfinished)}")
    IO.puts("  - Performing: #{length(performing)}")
    IO.puts("  - Enqueued: #{length(enqueued)}")
  end)
end

# Test 3: Verify cross-language concurrency works
IO.puts("\nTest 3: Verifying cross-language concurrency enforcement")
IO.puts(String.duplicate("-", 60))

# Query all jobs with a specific concurrency_key (regardless of queue)
test_key = "resource:resource-123"

all_jobs_with_key =
  repo.all(
    from(j in Job,
      where: j.concurrency_key == ^test_key and is_nil(j.finished_at),
      order_by: [asc: j.inserted_at]
    )
  )

if Enum.empty?(all_jobs_with_key) do
  IO.puts("No jobs found with concurrency_key '#{test_key}'")
  IO.puts("Run the Ruby test script first to enqueue jobs.")
else
  performing_count =
    Enum.count(all_jobs_with_key, &not is_nil(&1.locked_by_id))

  IO.puts("Jobs with concurrency_key '#{test_key}':")
  IO.puts("  - Total unfinished: #{length(all_jobs_with_key)}")
  IO.puts("  - Currently performing: #{performing_count}")
  IO.puts("  - Enqueued (waiting): #{length(all_jobs_with_key) - performing_count}")

  if performing_count <= 2 do
    IO.puts("\n✓ Concurrency limit (2) is being respected!")
  else
    IO.puts("\n✗ WARNING: More than 2 jobs are performing concurrently!")
    IO.puts("  This suggests concurrency limits may not be working correctly.")
  end
end

# Test 4: Check that concurrency_key is in serialized_params
IO.puts("\nTest 4: Verifying concurrency_key in serialized_params")
IO.puts(String.duplicate("-", 60))

if not Enum.empty?(jobs_with_key) do
  sample_job = List.first(jobs_with_key)
  concurrency_key_in_params = Map.get(sample_job.serialized_params, "good_job_concurrency_key")

  IO.puts("Sample job (#{sample_job.active_job_id}):")
  IO.puts("  - concurrency_key (DB column): #{sample_job.concurrency_key}")
  IO.puts("  - good_job_concurrency_key (serialized_params): #{concurrency_key_in_params}")

  if sample_job.concurrency_key == concurrency_key_in_params do
    IO.puts("\n✓ Concurrency key matches between DB and serialized_params")
  else
    IO.puts("\n✗ WARNING: Concurrency key mismatch!")
  end
end

IO.puts("\n" <> String.duplicate("=", 60))
IO.puts("Test complete!")
IO.puts("\nKey points:")
IO.puts("  1. Concurrency limits are enforced across Ruby and Elixir workers")
IO.puts("  2. Both workers query the same good_jobs table using concurrency_key")
IO.puts("  3. The concurrency_key is stored in both the DB column and serialized_params")
IO.puts("  4. Limits apply to ALL jobs with the same concurrency_key, regardless of language")
