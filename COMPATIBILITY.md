# Ruby GoodJob Compatibility

This Elixir implementation of GoodJob is designed to be **fully compatible** with Ruby GoodJob when sharing the same database schema and conventions as Protocol.

This allows you to:

- Process jobs from Rails/GoodJob in Elixir/Phoenix
- Process jobs from Elixir/Phoenix in Rails/GoodJob
- Share the same job queue across both ecosystems

## Database Schema Compatibility

Both implementations share the same Protocol tables and columns (`good_jobs`, `good_job_processes`, `good_job_executions`, batches, settings).

Indexes and tables are intended to match Ruby GoodJob 4.24.x. Elixir ships additive migrations (`add_good_job_parity_indexes`, `add_index_good_jobs_discarded_job_class`, `add_good_job_ruby_4_24_schema_parity`) for indexes and the `good_job_concurrency_claims` table that older Elixir installs may lack. Shared databases that already ran Ruby's update migrations are fine: new objects use `IF NOT EXISTS`.

Priority ordering for dequeue is ascending (smaller priority first), matching Ruby GoodJob v4. Queue-scoped dequeue indexes (`index_good_jobs_dequeue_by_queue*`) match Ruby update migration 16.

Ruby GoodJob v5 will remove `good_jobs.concurrency_key` and require label-based concurrency. Elixir still stores and honors `concurrency_key` for shared-database compatibility, and logs a one-time deprecation warning when key-only limits are used.

Prefer labels now:

```elixir
use GoodJob.Job

def good_job_concurrency_config do
  [label: "user-sync", total_limit: 1]
end
```

Jobs get that label on enqueue. Perform limits use `good_job_concurrency_claims` (grant/wait/promote) when the table exists, matching Ruby 4.21+. `good_jobs.id` is aligned with `active_job_id` on create, matching Ruby's discrete job identity for claims.

## Retry & Error Logic Compatibility ✅

### Max Attempts
- **Default**: `5` (matches Ruby GoodJob's `retry_on` default `attempts: 5`)
- Configurable per job via `use GoodJob.Job, max_attempts: 10`

### Backoff Strategy
- **Default**: Constant 3 seconds (matches Ruby GoodJob's ActiveJob `retry_on` default `wait: 3`)
- **Ruby-compatible**: Constant backoff with 15% jitter by default (matches Ruby ActiveJob's default jitter)
- **Additional strategies**: Exponential, linear, and polynomial backoff available
- Customizable via `backoff/1` callback

### Jitter Calculation
- **Matches Ruby**: Additive-only jitter (`rand * delay * jitter`)
- Same behavior as Ruby GoodJob's `Kernel.rand * delay * jitter`

## Usage Patterns

### Elixir Job (Compatible with Ruby GoodJob)

```elixir
defmodule MyApp.Jobs.ProcessOrder do
  use GoodJob.Job,
    queue: "default",
    max_attempts: 5,  # Matches Ruby GoodJob default
    priority: 0

  # Default backoff is constant 3 seconds (matches Ruby GoodJob's ActiveJob default)
  # No need to override unless you want a different strategy

  def perform(%{order_id: order_id}) do
    # Process order
    case MyApp.Orders.process(order_id) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}  # Will retry
    end
  end
end
```

### Ruby Job (Compatible with Elixir GoodJob)

```ruby
class ProcessOrderJob < ApplicationJob
  queue_as :default
  
  retry_on StandardError, attempts: 5, wait: 3.seconds
  
  def perform(order_id)
    MyApp::Orders.process(order_id)
  end
end
```

Both jobs will:
- Share the same `good_jobs` table
- Use the same retry logic (5 attempts)
- Use the same backoff strategy (3 seconds constant)
- Be processable by either Ruby or Elixir workers

## Differences (By Design)

### Error Handling Paradigm

**Ruby GoodJob (ActiveJob):**
```ruby
class MyJob < ApplicationJob
  retry_on SomeError, attempts: 5
  discard_on AnotherError
  
  def perform(args)
    raise SomeError if something_wrong
  end
end
```

**Elixir GoodJob:**
```elixir
defmodule MyJob do
  use GoodJob.Job, max_attempts: 5
  
  def perform(args) do
    if something_wrong do
      {:error, "reason"}  # Will retry
    else
      :ok
    end
  end
end
```

Both approaches are functionally equivalent but use different paradigms:
- **Ruby**: Exception-based (Rails convention)
- **Elixir**: Explicit return values (Elixir convention)

### Default Backoff

- **Ruby GoodJob**: Constant 3 seconds (default in `retry_on`)
- **Elixir GoodJob**: Constant 3 seconds (aligned with Ruby GoodJob)

Both implementations now use the same default backoff strategy. To use a different strategy:
```elixir
# Use exponential backoff
def backoff(attempt), do: GoodJob.Backoff.exponential(attempt)

# Use polynomial backoff (matches Ruby's :polynomially_longer)
def backoff(attempt), do: GoodJob.Backoff.polynomial(attempt)
```

## Advisory lock default

- Ruby GoodJob defaults to session-level `pg_try_advisory_lock` for many lock paths.
- Elixir GoodJob defaults `:advisory_lock_function` to `:pg_try_advisory_xact_lock` (transaction-scoped) for transactional claim and concurrency checks.
- Session locks are still used for process heartbeat and `:hybrid` dequeue SQL.
- Do not flip the Elixir default casually when sharing a database; configure `:advisory_lock_function` / `GOOD_JOB_ADVISORY_LOCK_FUNCTION` if you need session locks on the Elixir side.

## Lock strategy rolling migrate (toward Ruby v5)

Elixir default remains `:advisory`. Ruby GoodJob v5 is expected to default to `:skiplocked`. To move a shared database safely:

1. Deploy all workers on `:hybrid` (sees both advisory and row locks).
2. Wait until no `:advisory`-only workers remain.
3. Deploy `:skiplocked` and disable LISTEN/NOTIFY if using PgBouncer transaction mode (`enable_listen_notify: false`, rely on `poll_interval`).

Do not run `:advisory` and `:skiplocked` workers against the same database at the same time.

## Dequeue sort and threads naming

- `:dequeue_query_sort` — `:created_at` (default) or `:scheduled_at` (Ruby v5 direction). Env: `GOOD_JOB_DEQUEUE_QUERY_SORT`.
- `:threads` — preferred alias for `:max_processes` (Ruby renamed `max_threads` → `threads`). Env: `GOOD_JOB_THREADS`.

## High-throughput recipe (Elixir default stays `:advisory`)

Elixir keeps `:advisory` as the default for shared-database safety with older Ruby workers. For a single-language or already-migrated high-volume queue, prefer this shape without flipping the library default:

1. **`lock_strategy: :skiplocked`** (or roll through `:hybrid` first on a shared DB — see above).
2. **`GoodJob.Bulk.enqueue/1`** for producer bursts (chunked `insert_all`, one `NOTIFY`).
3. **Bound `threads` / `max_processes`** around **8–16** per queue pool on one Postgres primary; more threads often raise contention rather than jobs/s.
4. **`preserve_job_records: false`** when finished job/execution history is not required — deletes the job and its `good_job_executions` rows on success so dequeue indexes stay small.
5. Size the Ecto pool at least as large as concurrent workers plus notifier connections.

Maintainer load harness: `MIX_ENV=dev mix bench.load` (`benchmarks/load.exs`). Numbers vary by host; treat them as relative, not SLOs.

## Best Practices

1. Use consistent `max_attempts` across Ruby and Elixir jobs in the same queue
2. Keep the default constant backoff when you need Ruby ActiveJob `retry_on` parity; override `backoff/1` for exponential or other strategies
3. Test job processing from both sides when sharing a queue
4. Run Elixir migrations (including parity indexes) on shared databases that were created only from older Elixir installs
5. For high enqueue/dequeue volume, use the high-throughput recipe above instead of raising `threads` alone

## Migration Notes

If you're migrating from Ruby GoodJob to Elixir GoodJob:

1. Confirm schema and indexes: Ruby update migrations or Elixir's install plus `add_good_job_parity_indexes`
2. Update job definitions from ActiveJob to `use GoodJob.Job`
3. Update error handling from exceptions to explicit returns
4. Test retry and claim behavior on the shared database

