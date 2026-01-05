# Ruby GoodJob Compatibility

This Elixir implementation of GoodJob is designed to be **fully compatible** with Ruby GoodJob when sharing the same database schema and conventions as Protocol.

This allows you to:

- Process jobs from Rails/GoodJob in Elixir/Phoenix
- Process jobs from Elixir/Phoenix in Rails/GoodJob
- Share the same job queue across both ecosystems

## Database Schema Compatibility ✅

Both implementations use the **exact same database schema**:
- `good_jobs` table with identical columns
- `good_job_processes` table for process tracking
- `good_job_executions` table for execution history
- Same indexes and constraints

No schema changes needed when sharing a database between Ruby and Elixir applications.

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

## Best Practices

1. **Use consistent `max_attempts`** across Ruby and Elixir jobs in the same queue
2. **Use constant backoff** if you need exact Ruby GoodJob behavior
3. **Use exponential backoff** for better Elixir ecosystem alignment (default)
4. **Test job processing** from both sides to ensure compatibility

## Migration Notes

If you're migrating from Ruby GoodJob to Elixir GoodJob:

1. **No schema changes needed** - our migrations match Ruby's exactly
2. **Update job definitions** - convert from ActiveJob to `use GoodJob.Job`
3. **Update error handling** - convert from exceptions to explicit returns
4. **Test thoroughly** - ensure retry logic behaves as expected

