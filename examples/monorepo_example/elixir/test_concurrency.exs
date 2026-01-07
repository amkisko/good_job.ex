# Test script for concurrency configuration in Elixir
# Run with: mix run test_concurrency.exs

alias GoodJob.{Concurrency, Job, Repo}

# Setup: Ensure we have a repo
repo = Repo.repo()

IO.puts("Testing Concurrency Configuration in Elixir")
IO.puts(String.duplicate("=", 50))

# Test 1: Check enqueue limit
IO.puts("\nTest 1: Testing enqueue_limit")
IO.puts(String.duplicate("-", 50))

concurrency_key = "test-enqueue-key-#{System.system_time(:second)}"
config = %{enqueue_limit: 2}

# First job should be allowed
result1 = Concurrency.check_enqueue_limit(concurrency_key, config)
IO.puts("First job: #{inspect(result1)}")

# Create a job to simulate enqueued state
{:ok, _job1} =
  Job.enqueue(%{
    active_job_id: Ecto.UUID.generate(),
    job_class: "ConcurrencyTestJob",
    queue_name: "ex.default",
    serialized_params: %{"arguments" => []},
    concurrency_key: concurrency_key
  })

# Second job should be allowed
result2 = Concurrency.check_enqueue_limit(concurrency_key, config)
IO.puts("Second job: #{inspect(result2)}")

# Create another job
{:ok, _job2} =
  Job.enqueue(%{
    active_job_id: Ecto.UUID.generate(),
    job_class: "ConcurrencyTestJob",
    queue_name: "ex.default",
    serialized_params: %{"arguments" => []},
    concurrency_key: concurrency_key
  })

# Third job should be blocked
result3 = Concurrency.check_enqueue_limit(concurrency_key, config)
IO.puts("Third job (should be blocked): #{inspect(result3)}")

case result3 do
  {:ok, {:error, :limit_exceeded}} ->
    IO.puts("✓ Enqueue limit working correctly")

  other ->
    IO.puts("✗ Enqueue limit not working: #{inspect(other)}")
end

# Test 2: Check perform limit
IO.puts("\nTest 2: Testing perform_limit")
IO.puts(String.duplicate("-", 50))

perform_key = "test-perform-key-#{System.system_time(:second)}"
perform_config = %{perform_limit: 2}

# Create jobs that are "performing" (locked)
job_id1 = Ecto.UUID.generate()
job_id2 = Ecto.UUID.generate()
job_id3 = Ecto.UUID.generate()

{:ok, _job1} =
  Job.enqueue(%{
    active_job_id: job_id1,
    job_class: "ConcurrencyTestJob",
    queue_name: "ex.default",
    serialized_params: %{"arguments" => []},
    concurrency_key: perform_key,
    locked_by_id: Ecto.UUID.generate(),
    locked_at: DateTime.utc_now()
  })

{:ok, _job2} =
  Job.enqueue(%{
    active_job_id: job_id2,
    job_class: "ConcurrencyTestJob",
    queue_name: "ex.default",
    serialized_params: %{"arguments" => []},
    concurrency_key: perform_key,
    locked_by_id: Ecto.UUID.generate(),
    locked_at: DateTime.utc_now()
  })

# Check if third job can perform
result_perform = Concurrency.check_perform_limit(perform_key, job_id3, perform_config)
IO.puts("Third job perform check: #{inspect(result_perform)}")

case result_perform do
  {:ok, {:error, :limit_exceeded}} ->
    IO.puts("✓ Perform limit working correctly")

  other ->
    IO.puts("✗ Perform limit not working: #{inspect(other)}")
end

# Test 3: Check total_limit
IO.puts("\nTest 3: Testing total_limit")
IO.puts(String.duplicate("-", 50))

total_key = "test-total-key-#{System.system_time(:second)}"
total_config = %{total_limit: 2}

# Create one enqueued and one performing job
{:ok, _job1} =
  Job.enqueue(%{
    active_job_id: Ecto.UUID.generate(),
    job_class: "ConcurrencyTestJob",
    queue_name: "ex.default",
    serialized_params: %{"arguments" => []},
    concurrency_key: total_key
  })

{:ok, _job2} =
  Job.enqueue(%{
    active_job_id: Ecto.UUID.generate(),
    job_class: "ConcurrencyTestJob",
    queue_name: "ex.default",
    serialized_params: %{"arguments" => []},
    concurrency_key: total_key,
    locked_by_id: Ecto.UUID.generate(),
    locked_at: DateTime.utc_now()
  })

# Third job should be blocked (total = 2)
result_total = Concurrency.check_enqueue_limit(total_key, total_config)
IO.puts("Third job with total_limit: #{inspect(result_total)}")

case result_total do
  {:ok, {:error, :limit_exceeded}} ->
    IO.puts("✓ Total limit working correctly")

  other ->
    IO.puts("✗ Total limit not working: #{inspect(other)}")
end

IO.puts("\n" <> String.duplicate("=", 50))
IO.puts("Test complete!")
