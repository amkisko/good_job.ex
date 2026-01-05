# Migration Guide: good_job (Ruby) to good_job.ex (Elixir)

This guide helps you migrate from the Ruby `good_job` gem to the Elixir `good_job` library.

**For compatibility details when running both Ruby and Elixir together**, see [COMPATIBILITY.md](COMPATIBILITY.md).

## Overview

Both libraries provide a concurrent, Postgres-based job queue backend with the same database schema, but there are differences in API and integration patterns due to the different ecosystems (Rails vs Phoenix/Elixir).

## API Mapping

### Job Definition

**Ruby (Rails/ActiveJob):**
```ruby
class MyJob < ApplicationJob
  queue_as :high_priority
  
  def perform(data)
    # Your job logic here
    puts "Processing: #{data}"
  end
end

# Enqueue the job
MyJob.perform_later(data: "hello")
```

**Elixir:**
```elixir
defmodule MyApp.MyJob do
  use GoodJob.Job, queue: "high_priority"

  @impl GoodJob.Behaviour
  def perform(%{data: data}) do
    # Your job logic here
    IO.puts("Processing: #{data}")
  end
end

# Enqueue the job
MyApp.MyJob.enqueue(%{data: "hello"})
```

### Configuration

**Ruby (Rails):**
```ruby
# config/initializers/good_job.rb
Rails.application.configure do
  config.good_job = {
    execution_mode: :external,
    max_processes: 5,
    queues: "*",
    poll_interval: 10
  }
end
```

**Elixir:**
```elixir
# config/config.exs
config :good_job,
  repo: MyApp.Repo,
  execution_mode: :external,
  max_processes: 5,
  queues: "*",
  poll_interval: 10
```

### Execution Modes

Both libraries support the same execution modes. See [README.md](README.md) for details.

### Cron Jobs

**Ruby:**
```ruby
# config/initializers/good_job.rb
Rails.application.configure do
  config.good_job.cron = {
    example: {
      cron: "0 * * * *",  # Every hour
      class: "ExampleJob"
    }
  }
end
```

**Elixir:**
```elixir
# config/config.exs
config :good_job,
  cron: [
    example: [
      cron: "0 * * * *",  # Every hour
      job: ExampleJob
    ]
  ]
```

### Batches

**Ruby:**
```ruby
batch = GoodJob::Batch.new(
  description: "Process users",
  on_finish: "BatchFinishedJob"
)

User.find_each do |user|
  ProcessUserJob.perform_later(user.id, batch_id: batch.id)
end
```

**Elixir:**
```elixir
batch = GoodJob.Batch.create(%{
  description: "Process users",
  on_finish: "BatchFinishedJob"
})

User
|> Repo.all()
|> Enum.each(fn user ->
  ProcessUserJob.enqueue(%{user_id: user.id}, batch_id: batch.id)
end)
```

### Concurrency Controls

**Ruby:**
```ruby
class ProcessUserJob < ApplicationJob
  def perform(user_id)
    # Job logic
  end
  
  def good_job_concurrency_key
    "user_#{user_id}"
  end
  
  def good_job_concurrency_limit
    5
  end
end
```

**Elixir:**
```elixir
defmodule ProcessUserJob do
  use GoodJob.Job

  @impl GoodJob.Behaviour
  def perform(%{user_id: user_id}) do
    # Job logic
  end
  
  def good_job_concurrency_config do
    [key: fn %{user_id: user_id} -> "user_#{user_id}" end, limit: 5]
  end
end
```

### Retries

Both libraries support automatic retries. Default max attempts is `5` (matches Ruby GoodJob). See [COMPATIBILITY.md](COMPATIBILITY.md) for retry and backoff compatibility details.

### Testing

See [README.md](README.md) for testing examples.

## Key Differences

### 1. Job Definition

- **Ruby**: Uses ActiveJob base class with `perform` method
- **Elixir**: Uses `use GoodJob.Job` macro with `@impl GoodJob.Behaviour` and `perform/1` callback

### 2. Error Handling

- **Ruby**: Exception-based (Rails convention) - `raise` exceptions for errors
- **Elixir**: Explicit return values (Elixir convention) - `{:error, reason}` for errors

### 3. Process Model

- **Ruby**: Uses OS threads (via Concurrent Ruby)
- **Elixir**: Uses OTP processes (GenServer, Task.Supervisor)

### 4. Configuration Parameter Names

- **Ruby**: `max_threads`
- **Elixir**: `max_processes` (same functionality, different terminology)

### 5. Database Schema

The database schema is fully compatible. You can use the same migrations and share the same database.

## Migration Steps

1. **Install the Elixir package**:
   ```elixir
   # mix.exs
   {:good_job, "~> 0.1.0"}
   ```

2. **Run migrations** (if not already done):
   ```bash
   mix good_job.install
   mix ecto.migrate
   ```

3. **Convert job definitions**:
   - Convert ActiveJob classes to Elixir modules using `use GoodJob.Job`
   - Update method signatures to use pattern matching
   - Convert Ruby hash arguments to Elixir maps

4. **Update configuration**:
   - Move from Rails initializers to Elixir config files
   - Update configuration syntax

5. **Update tests**:
   - Replace ActiveJob test helpers with `GoodJob.Testing`
   - Update assertions to use Elixir syntax

6. **Update deployment**:
   - Replace `bundle exec good_job start` with `mix good_job.start` (when available)
   - Or use `:async` mode for in-process execution

## Compatibility Notes

- The database schema is fully compatible - you can use the same PostgreSQL database
- Job records created by Ruby version can be processed by Elixir version (and vice versa)
- Cron job definitions need to be converted to Elixir syntax
- Batch callbacks need to be converted to Elixir job modules

For detailed compatibility information when running both Ruby and Elixir together, see [COMPATIBILITY.md](COMPATIBILITY.md).

## Getting Help

If you encounter issues during migration:

1. Check the [documentation](https://hexdocs.pm/good_job)
2. Open an issue on GitHub
3. Review the [CHANGELOG.md](CHANGELOG.md) for recent changes

