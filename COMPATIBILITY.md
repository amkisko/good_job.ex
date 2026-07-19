# Ruby GoodJob Compatibility

This Elixir implementation of GoodJob is designed to be **fully compatible** with Ruby GoodJob when sharing the same database schema and conventions as Protocol.

This allows you to:

- Process jobs from Rails/GoodJob in Elixir/Phoenix
- Process jobs from Elixir/Phoenix in Rails/GoodJob
- Share the same job queue across both ecosystems

## Database Schema Compatibility

Both implementations share the same Protocol tables and columns (`good_jobs`, `good_job_processes`, `good_job_executions`, batches, settings).

Indexes are intended to match Ruby GoodJob 4.x. Elixir ships an additive migration (`add_good_job_parity_indexes`) for indexes that older Elixir installs may lack. Shared databases that already ran Ruby's update migrations are fine: new indexes use `IF NOT EXISTS`.

Priority ordering for dequeue is ascending (smaller priority first), matching Ruby GoodJob v4.

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

## Best Practices

1. Use consistent `max_attempts` across Ruby and Elixir jobs in the same queue
2. Keep the default constant backoff when you need Ruby ActiveJob `retry_on` parity; override `backoff/1` for exponential or other strategies
3. Test job processing from both sides when sharing a queue
4. Run Elixir migrations (including parity indexes) on shared databases that were created only from older Elixir installs

## Migration Notes

If you're migrating from Ruby GoodJob to Elixir GoodJob:

1. Confirm schema and indexes: Ruby update migrations or Elixir's install plus `add_good_job_parity_indexes`
2. Update job definitions from ActiveJob to `use GoodJob.Job`
3. Update error handling from exceptions to explicit returns
4. Test retry and claim behavior on the shared database

