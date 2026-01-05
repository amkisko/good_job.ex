# GoodJob Standalone Usage (Without Phoenix)

GoodJob is designed to work **standalone without Phoenix**. The core job queue functionality requires only:

- **Ecto** - For database operations
- **PostgreSQL** - As the job queue backend
- **Jason** - For JSON serialization
- **Telemetry** - For instrumentation

Phoenix dependencies (`phoenix`, `phoenix_live_view`, `phoenix_html`, `plug`, `plug_cowboy`) are marked as `optional: true` and only needed for the web dashboard and real-time updates.

## What Works Without Phoenix

✅ **All core functionality** works without Phoenix:
- Job enqueueing and execution
- Job scheduling and cron jobs
- Batch operations
- Concurrency controls
- Retry logic with exponential backoff
- LISTEN/NOTIFY for low-latency dispatch
- Advisory locks for run-once safety
- Cleanup and maintenance operations
- Health checks and monitoring

❌ **Optional features** that require Phoenix:
- `GoodJob.PubSub` - Real-time event broadcasting (gracefully no-ops if Phoenix unavailable)
- `GoodJob.Web.LiveDashboard` - Web-based monitoring dashboard
- `GoodJob.Web.LiveDashboardPage` - Phoenix LiveDashboard integration

## Usage Without Phoenix

### 1. Basic Setup

```elixir
# mix.exs
defp deps do
  [
    {:good_job, "~> 0.1.0"},
    {:ecto_sql, "~> 3.10"},
    {:postgrex, "~> 0.20"}
    # No Phoenix dependencies needed!
  ]
end
```

### 2. Configuration

```elixir
# config/config.exs
config :good_job,
  repo: MyApp.Repo,
  execution_mode: :async,
  max_processes: 5,
  queues: "*",
  poll_interval: 10
```

See [README.md](README.md) for complete configuration options.

### 3. Application Setup

```elixir
# lib/my_app/application.ex
defmodule MyApp.Application do
  use Application

  def start(_type, _args) do
    children = [
      MyApp.Repo,
      GoodJob.Supervisor  # Start GoodJob supervisor
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
```

### 4. Define and Enqueue Jobs

```elixir
# lib/my_app/jobs/email_job.ex
defmodule MyApp.Jobs.EmailJob do
  use GoodJob.Job, queue: "emails"

  @impl GoodJob.Behaviour
  def perform(%{to: to, subject: subject, body: body}) do
    # Send email logic
    IO.puts("Sending email to #{to}: #{subject}")
    :ok
  end
end

# Enqueue a job
MyApp.Jobs.EmailJob.enqueue(%{
  to: "user@example.com",
  subject: "Hello",
  body: "World"
})
```

## PubSub Behavior Without Phoenix

The `GoodJob.PubSub` module automatically detects if Phoenix is available:
- **With Phoenix:** Broadcasts events to `Phoenix.PubSub` for real-time updates
- **Without Phoenix:** Gracefully no-ops (returns `:noop`)

All core modules call `GoodJob.PubSub.broadcast()` but it's safe - it won't crash if Phoenix isn't available.

## Monitoring Without Web Dashboard

Without the web dashboard, you can still monitor GoodJob:

### 1. Telemetry Events

```elixir
defmodule MyApp.Telemetry do
  def handle_event([:good_job, :job, :enqueue], _measure, meta, _config) do
    IO.inspect(meta, label: "Job enqueued")
  end

  def handle_event([:good_job, :job, :success], measure, meta, _config) do
    IO.inspect({measure, meta}, label: "Job succeeded")
  end
end
```

### 2. Health Checks

```elixir
# Perform comprehensive health check
case GoodJob.HealthCheck.check() do
  {:ok, status} -> IO.inspect(status, label: "Healthy")
  {:error, reason} -> IO.puts("Unhealthy: #{reason}")
end

# Get simple health status string
GoodJob.HealthCheck.status()  # Returns "healthy" or "unhealthy"

# Get job statistics
GoodJob.stats()
GoodJob.stats("queue_name")
```

### 3. Direct Database Queries

```elixir
# Query jobs directly
import Ecto.Query
alias GoodJob.Job

# Get queued jobs
Job.queued() |> MyApp.Repo.all()

# Get running jobs
Job.running() |> MyApp.Repo.all()

# Get failed jobs
Job.discarded() |> MyApp.Repo.all()
```

## Migration Path

If you start without Phoenix and later want to add it:

1. Add Phoenix dependencies to `mix.exs`
2. Configure `pubsub_server` in your config
3. The PubSub module will automatically start working
4. Optionally add the web dashboard routes

No code changes needed in your job definitions or core application logic!

## Example: Standalone Elixir Application

```elixir
# mix.exs
defmodule MyWorkerApp.MixProject do
  use Mix.Project

  def project do
    [
      app: :my_worker_app,
      version: "0.1.0",
      elixir: "~> 1.18",
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {MyWorkerApp.Application, []}
    ]
  end

  defp deps do
    [
      {:good_job, "~> 0.1.0"},
      {:ecto_sql, "~> 3.10"},
      {:postgrex, "~> 0.20"}
      # No Phoenix!
    ]
  end
end

# lib/my_worker_app/application.ex
defmodule MyWorkerApp.Application do
  use Application

  def start(_type, _args) do
    children = [
      MyWorkerApp.Repo,
      GoodJob.Supervisor
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end

# lib/my_worker_app/jobs/worker_job.ex
defmodule MyWorkerApp.Jobs.WorkerJob do
  use GoodJob.Job

  @impl GoodJob.Behaviour
  def perform(%{task: task}) do
    # Do work
    Process.sleep(1000)
    IO.puts("Completed: #{task}")
    :ok
  end
end
```

This application will run jobs perfectly fine without any Phoenix dependencies!

