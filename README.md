# good_job for elixir

[![Hex Version](https://img.shields.io/hexpm/v/good_job.svg)](https://hex.pm/packages/good_job)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/good_job)
[![Test Status](https://github.com/amkisko/good_job.ex/actions/workflows/test.yml/badge.svg)](https://github.com/amkisko/good_job.ex/actions/workflows/test.yml)
[![codecov](https://codecov.io/gh/amkisko/good_job.ex/graph/badge.svg?token=Q0WMBFW7IU)](https://codecov.io/gh/amkisko/good_job.ex)

Concurrent, Postgres-based job queue backend for Elixir. Provides attribute-based job execution with PostgreSQL advisory locks to ensure run-once safety. Works with Phoenix and can be used standalone in other Elixir frameworks or plain Elixir applications.

**Port of [GoodJob](https://github.com/bensheldon/good_job)** - This Elixir implementation is a port of the excellent Ruby GoodJob gem by [Ben Sheldon](https://github.com/bensheldon), designed for maximum compatibility with the original, to make it possible running both Ruby and Elixir applications with the same database. It fully implements the protocol that respects GoodJob and ActiveJob conventions. This implementation allows moving forward to other languages and frameworks that implement the same protocol.

**Need Ruby compatibility details?** See [COMPATIBILITY.md](COMPATIBILITY.md) for compatibility information.

**Migrating from the Ruby version?** See [MIGRATION_FROM_RUBY.md](MIGRATION_FROM_RUBY.md) for a detailed guide.

**Using without Phoenix?** See [STANDALONE.md](STANDALONE.md) for standalone usage.

## Features

- **PostgreSQL Backend** - Relies upon Postgres integrity, session-level Advisory Locks to provide run-once safety
- **LISTEN/NOTIFY** - Uses PostgreSQL LISTEN/NOTIFY to reduce queuing latency
- **Multiple Execution Modes** - Inline (testing), async (development), external (production)
- **Queue Management** - Support for ordered queues, queue-specific concurrency, and semicolon-separated pools
- **Cron Jobs** - Scheduled jobs with cron expressions
- **Batch Operations** - Batch job tracking and callbacks
- **Concurrency Controls** - Per-key concurrency limits and throttling
- **Retry Mechanisms** - Automatic retries with exponential backoff
- **Plugins System** - Extensible plugin architecture for custom functionality
- **Labels/Tags** - Tag jobs for filtering and analytics
- **Web Dashboard** - Phoenix LiveView dashboard for monitoring and management
- **Ruby-Compatible** - Fully aligned with Ruby GoodJob configuration and database schema
- **Comprehensive Instrumentation** - Telemetry events for monitoring and metrics
- **Production Ready** - Designed for applications that enqueue 1-million jobs/day and more

## Installation

Add `good_job` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:good_job, "~> 0.1.1"}
  ]
end
```

For Phoenix LiveView dashboard support, also ensure you have:

```elixir
{:phoenix_live_view, "~> 0.20"}
```

## Quick Start

### 1. Install the Database Migrations

```bash
mix good_job.install
mix ecto.migrate
```

### 2. Configure GoodJob

```elixir
# config/config.exs
config :good_job,
  repo: MyApp.Repo,
  execution_mode: :external,  # :inline (test), :async (dev), :external (prod)
  queues: "*",
  max_processes: 5
```

### 3. Start GoodJob in Your Application

```elixir
# lib/my_app/application.ex
defmodule MyApp.Application do
  use Application

  def start(_type, _args) do
    children = [
      MyApp.Repo,
      GoodJob.Application
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
```

### 4. Define and Enqueue a Job

```elixir
defmodule MyApp.MyJob do
  use GoodJob.Job

  @impl GoodJob.Behaviour
  def perform(%{data: data}) do
    # Your job logic here
    IO.puts("Processing: #{inspect(data)}")
    :ok
  end
end

# Enqueue the job
MyApp.MyJob.enqueue(%{data: "hello"})
```

## Usage

### Basic Job

```elixir
defmodule MyApp.EmailJob do
  use GoodJob.Job, queue: "emails", priority: 1

  @impl GoodJob.Behaviour
  def perform(%{to: to, subject: subject, body: body}) do
    MyApp.Mailer.send(to: to, subject: subject, body: body)
    :ok
  end
end

MyApp.EmailJob.enqueue(%{to: "user@example.com", subject: "Hello", body: "World"})
```

### Labeled Jobs (Tags)

```elixir
defmodule MyApp.TaggedJob do
  use GoodJob.Job, tags: ["billing", "priority"]

  @impl GoodJob.Behaviour
  def perform(_args), do: :ok
end

MyApp.TaggedJob.enqueue(%{user_id: 123}, tags: ["vip"])
```

### Job with Retries

```elixir
defmodule MyApp.ApiJob do
  use GoodJob.Job, max_attempts: 10

  @impl GoodJob.Behaviour
  def perform(%{url: url}) do
    case HTTPoison.get(url) do
      {:ok, response} -> {:ok, response.body}
      {:error, reason} -> {:error, reason}  # Will retry
    end
  end

  def backoff(attempt) do
    GoodJob.Backoff.exponential(attempt, max: 300)
  end
end
```

### Cron Jobs

```elixir
# config/config.exs
config :good_job,
  enable_cron: true,
  cron: %{
    cleanup: %{
      cron: "0 2 * * *",  # Every day at 2 AM
      class: MyApp.CleanupJob,
      args: %{},
      queue: "default"
    }
  }
```

### Batch Jobs

```elixir
batch = GoodJob.Batch.create(%{
  description: "Process users",
  on_finish: "MyApp.BatchFinishedJob"
})

User
|> Repo.all()
|> Enum.each(fn user ->
  ProcessUserJob.enqueue(%{user_id: user.id}, batch_id: batch.id)
end)
```

### Concurrency Controls

```elixir
defmodule MyApp.UserJob do
  use GoodJob.Job

  @impl GoodJob.Behaviour
  def perform(%{user_id: user_id}) do
    # Process user
  end

  def good_job_concurrency_config do
    [
      key: fn %{user_id: user_id} -> "user_#{user_id}" end,
      limit: 5,
      perform_throttle: {10, 60} # max 10 executions per 60s for the key
    ]
  end
end
```

### Throttling Only (No Concurrency Limit)

```elixir
defmodule MyApp.ThrottledJob do
  use GoodJob.Job

  @impl GoodJob.Behaviour
  def perform(_args), do: :ok

  def good_job_concurrency_config do
    [
      key: fn _args -> "global" end,
      enqueue_throttle: {100, 60}
    ]
  end
end
```

## Queue Configuration

```elixir
# Process all queues
queues: "*"

# Comma-separated queues (legacy format)
queues: "queue1:5,queue2:10"

# Semicolon-separated pools (Ruby GoodJob format)
queues: "queue1:2;queue2:1;*"

# Ordered queues (process in order)
queues: "+queue1,queue2:5"

# Excluded queues
queues: "-queue1,queue2:2"
```

**Note:** Only `*` is supported as a wildcard (standalone, not in patterns like `queue*`).

## Execution Modes

- **`:inline`** - Execute immediately in current process (test/dev only)
- **`:async`** / **`:async_server`** - Execute in processes within web server process only
- **`:async_all`** - Execute in processes in any process
- **`:external`** - Enqueue only, requires separate worker process (production default)

## Configuration

```elixir
# config/config.exs
config :good_job,
  repo: MyApp.Repo,
  execution_mode: :external,
  queues: "*",
  max_processes: 5,
  poll_interval: 10,
  enable_listen_notify: true,
  enable_cron: false,
  cleanup_discarded_jobs: true,
  cleanup_preserved_jobs_before_seconds_ago: 1_209_600  # 14 days
```

See [config/prod.exs.example](config/prod.exs.example) for a complete configuration example with all available options.

## Web Dashboard

### Phoenix LiveDashboard Integration (Recommended)

```elixir
# lib/my_app_web/router.ex
import Phoenix.LiveDashboard.Router

live_dashboard "/dashboard",
  metrics: MyAppWeb.Telemetry,
  additional_pages: [
    good_job: GoodJob.Web.LiveDashboardPage
  ]
```

### Standalone Dashboard

```elixir
# lib/my_app_web/router.ex
scope "/good_job" do
  pipe_through :browser
  live "/", GoodJob.Web.LiveDashboard, :index
end
```

**Note**: The web dashboard requires Phoenix. For monitoring without Phoenix, see [STANDALONE.md](STANDALONE.md).

## Testing

```elixir
# config/test.exs
config :good_job,
  execution_mode: :inline

# In your tests
import GoodJob.Testing

test "job is enqueued" do
  MyApp.MyJob.enqueue(%{data: "test"})
  assert_enqueued(MyApp.MyJob, %{data: "test"})
end
```

## Requirements

- Elixir >= 1.18
- PostgreSQL >= 12
- Ecto >= 3.0
- Phoenix >= 1.7 (optional, for Phoenix integration)
- Phoenix LiveView >= 0.20 (optional, for LiveView dashboard)

**Note**: GoodJob can be used without Phoenix! See [STANDALONE.md](STANDALONE.md).

## Examples

Complete working examples are available in the [`examples/`](examples/) directory:

- **[habit_tracker](examples/habit_tracker/)** - A full Phoenix application demonstrating GoodJob integration with LiveView dashboard, cron jobs, and batch operations
- **[monorepo_example](examples/monorepo_example/)** - A monorepo setup showing Ruby and Elixir applications sharing the same GoodJob database

See [examples/README.md](examples/README.md) for more details.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/amkisko/good_job.ex

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## Credits

This Elixir implementation is a port of [GoodJob](https://github.com/bensheldon/good_job) by [Ben Sheldon](https://github.com/bensheldon). We are grateful for the excellent design and implementation of the original Ruby version, which served as the foundation for this port.

## License

The library is available as open source under the terms of the [MIT License](LICENSE.md).
