# Monorepo Example: Rails + Elixir + Zig GoodJob

This is an end-to-end working example of a monorepo application that demonstrates cross-language job processing using GoodJob. The Rails and Elixir apps enqueue jobs that are processed by Ruby, Elixir, and Zig workers running in parallel.

## Architecture

```
┌─────────────┐
│   Rails     │  Enqueues jobs via ActiveJob
│   API       │
└──────┬──────┘
       │
       ├───> ExampleJob → rb.default → Rails Worker
       ├───> ElixirProcessedJob → ex.default → Elixir Worker
       └───> ZigProcessedJob → zig.default → Zig Worker
       
┌─────────────┐
│   Elixir    │  Enqueues jobs via GoodJob.ex
│   API       │
└──────┬──────┘
       │
       ├───> MonorepoExample.Jobs.ProcessJob → ex.default → Elixir Worker
       └───> MonorepoExample.Jobs.ZigJob → zig.default → Zig Worker
```

### Components

- **Rails API**: Slim Rails 8.0 app with GoodJob adapter
- **Rails Worker**: Processes `rb.default` queue (Ruby jobs)
- **Elixir Worker**: Processes `ex.default` queue (Elixir jobs)
- **PostgreSQL**: Shared database for all systems

## Prerequisites

- Ruby 3.2+
- Rails 8.0+
- Elixir 1.18+
- PostgreSQL 14+
- Docker & Docker Compose (for containerized setup)
- Foreman (for local development)

## Quick Start

### Option 1: Docker Compose (Recommended)

The easiest way to get started with full isolation:

```bash
# Start all services
docker-compose up

# In another terminal, run database migrations
docker-compose exec rails bundle exec rails db:create db:migrate
docker-compose exec elixir mix ecto.create mix ecto.migrate

# Test the setup
curl -X POST http://localhost:3000/jobs/enqueue?job_type=example
curl -X POST http://localhost:3000/jobs/enqueue?job_type=elixir
```

### Option 2: Local Development with Foreman

1. **Set up PostgreSQL**:
   ```bash
   # Create database
   createdb monorepo_example_development
   ```

2. **Set up Rails**:
   ```bash
   cd rails
   bundle install
   bundle exec rails db:create db:migrate
   ```

3. **Set up Elixir**:
   ```bash
   cd elixir
   mix deps.get
   mix ecto.create
   mix ecto.migrate
   ```

4. **Run migrations**:
   ```bash
   # Rails GoodJob migration
   cd rails
   bundle exec rails generate good_job:install
   bundle exec rails db:migrate
   
   # Elixir GoodJob migration (if not already run)
   cd ../elixir
   mix good_job.install
   mix ecto.migrate
   ```

5. **Start all services**:
   
   **Recommended**: Use the start script (checks prerequisites and handles conflicts):
   ```bash
   # From the monorepo_example directory
   ./start.sh
   ```
   
   **Alternative**: Start foreman directly:
   ```bash
   foreman start
   ```

   This will start:
   - Rails API server on http://localhost:3000
   - Rails Tailwind CSS watcher
   - Rails GoodJob worker (processes `rb.default` queue)
   - Elixir GoodJob worker (processes `ex.default` queue)
   - Elixir Phoenix web server on http://localhost:4000

6. **Stopping services**:
   
   To stop foreman gracefully and prevent zombie processes:
   ```bash
   ./stop.sh
   ```
   
   Or if you need to clean up zombie processes and orphaned processes:
   ```bash
   ./cleanup.sh
   ```
   
   **Note**: Always use `./stop.sh` or press `Ctrl+C` in the foreman terminal to stop services gracefully. If processes become unresponsive or you see zombie processes, run `./cleanup.sh` to force-kill all related processes.

## Usage

### Enqueue a Ruby Job

```bash
curl -X POST http://localhost:3000/jobs/enqueue?job_type=example&message="Hello from Ruby"
```

This job will be processed by the Rails worker.

### Enqueue an Elixir Job

```bash
curl -X POST http://localhost:3000/jobs/enqueue?job_type=elixir&user_id=123&action=process
```

This job will be processed by the Elixir worker.

### View GoodJob Dashboard

Visit http://localhost:3000/good_job to see the GoodJob dashboard with all jobs.

## Project Structure

```
monorepo_example/
├── rails/                    # Rails API application
│   ├── app/
│   │   ├── controllers/
│   │   │   └── jobs_controller.rb
│   │   └── jobs/
│   │       ├── example_job.rb              # Ruby job
│   │       ├── elixir_processed_job.rb    # Elixir job (metadata only)
│   ├── config/
│   │   ├── application.rb
│   │   └── database.yml
│   └── Gemfile
├── elixir/                   # Elixir worker application
│   ├── lib/
│   │   └── monorepo_example/
│   │       ├── application.ex
│   │       ├── repo.ex
│   │       └── jobs/
│   │           ├── process_job.ex              # Elixir job implementation
│   │           ├── scheduled_elixir_job.ex       # Elixir cron job
│   │           ├── ruby_scheduled_wrapper_job.ex # Ruby job descriptor (for cron)
│   │           └── zig_job.ex                   # Zig job (metadata only)
│   ├── config/
│   │   └── config.exs
│   └── mix.exs
├── docker-compose.yml        # Docker Compose configuration
├── Procfile                  # Foreman configuration
└── README.md
```

## How It Works

### Cross-Language Job Processing

1. **Rails enqueues a job**:
   ```ruby
   ElixirProcessedJob.perform_later(user_id: 123, action: "process")
   ```

2. **GoodJob serializes the job** in ActiveJob format and stores it in PostgreSQL with:
   - `job_class`: "ElixirProcessedJob"
   - `queue_name`: "ex.default" (automatically prefixed)
   - `serialized_params`: JSON with job arguments

3. **Elixir worker picks up the job**:
   - Uses PostgreSQL LISTEN/NOTIFY for real-time job pickup (primary mechanism)
   - Falls back to polling every 30 seconds as a safety net
   - Resolves job module using `external_jobs` configuration (recommended) or fallback methods
   - Executes the job

### Queue Partitioning

- **Rails queues**: Use `rb.default` (or other specific queue names like `rb.emails`)
- **Elixir queues**: Use `ex.default` (or other specific queue names like `ex.emails`)
- **Zig queues**: Use `zig.default` (or other specific queue names like `zig.emails`)

Note: Ruby GoodJob doesn't support wildcard patterns. Use specific queue names separated by commas if you need multiple queues (e.g., `"ex.default,ex.emails"`).

### Job Module Resolution

**Elixir-native jobs** (enqueued from Elixir code) work automatically:
- No configuration needed
- Module names are resolved at runtime using `Code.ensure_loaded/1`
- Example: `MyApp.Jobs.MyJob` is automatically found when `job_class` is `"MyApp.Jobs.MyJob"`

**Cross-language jobs** (enqueued from external languages like Ruby Rails, Zig, etc.) require configuration:

**Recommended: Use `external_jobs` configuration** in `config/config.exs`:

```elixir
config :good_job, :config,
  external_jobs: %{
    "ElixirProcessedJob" => MonorepoExample.Jobs.ProcessJob,
    "MyRailsJob" => MyApp.Jobs.MyElixirJob
  }
```

This is the recommended approach because it:
- Follows Elixir configuration conventions
- Is explicit and easy to understand
- Doesn't require module scanning or loading
- Keeps your `application.ex` clean
- Works for any external language (Rails, Zig, etc.)

**Fallback method** (for external jobs not in `external_jobs`):

1. **Direct module name match**: If your Elixir module name matches the Ruby class name (after converting `::` to `.`), it will be found automatically.

### Job Pickup: LISTEN/NOTIFY vs Polling

Both Rails and Elixir workers use **PostgreSQL LISTEN/NOTIFY** as the primary mechanism for job pickup, which provides near-instantaneous job processing. Polling is configured as a fallback safety net.

**Configuration:**
- **Rails**: `poll_interval: 30` seconds (in `rails/config/initializers/good_job.rb`)
- **Elixir**: `poll_interval: 30` seconds (in `elixir/config/config.exs`)

**Why 30 seconds?**
- With LISTEN/NOTIFY enabled, polling is just a safety net in case notifications fail
- Ruby GoodJob recommends 30+ seconds when LISTEN/NOTIFY is enabled
- This reduces unnecessary database queries while maintaining reliability
- Jobs are picked up immediately via LISTEN/NOTIFY, so frequent polling is unnecessary

**Note**: If you see frequent polling (every second), it's likely the `notifier_wait_interval` (1 second), which is the LISTEN/NOTIFY mechanism checking for notifications, not actual database polling.

## Development

### Adding a New Cross-Language Job

#### Pattern 1: Descriptor Module (Recommended for Cron Jobs)

For scheduled/cron jobs, use the descriptor pattern to match Ruby's approach:

1. **Define job descriptor in Elixir** (`elixir/lib/monorepo_example/jobs/my_ruby_job.ex`):
   ```elixir
   defmodule MonorepoExample.Jobs.MyRubyJob do
     @moduledoc """
     This job will be processed by Ruby worker.
     The job logic is in Ruby, this is just metadata.
     """
     use GoodJob.ExternalJob, queue: "rb.default"

     @impl GoodJob.Behaviour
     def perform(_args) do
       raise "MyRubyJob must be processed by Ruby worker, not Elixir!"
     end
   end
   ```

2. **Implement job logic in Ruby** (`rails/app/jobs/my_ruby_job.rb`):
   ```ruby
   class MyRubyJob < ApplicationJob
     queue_as "rb.default"

     def perform(message:)
       Rails.logger.info "MyRubyJob processed: #{message}"
     end
   end
   ```

3. **Use in cron configuration**:
   ```elixir
   # config/config.exs
   config :good_job,
     cron: [
       my_job: [
         cron: "0 * * * *",
         class: MonorepoExample.Jobs.MyRubyJob,
         args: %{message: "Hello"},
         queue: "rb.default"
       ]
     ]
   ```

#### Pattern 2: Handler Registry (For Ad-Hoc Jobs)

For ad-hoc jobs enqueued from code:

1. **Define job metadata in Rails** (`rails/app/jobs/my_job.rb`):
   ```ruby
   class MyJob < ApplicationJob
     include GoodJob::ActiveJobExtensions::ElixirJob
     elixir_job_class "MonorepoExample.Jobs.MyJob"
     queue_as :my_queue
   end
   ```

2. **Implement job logic in Elixir** (`elixir/lib/monorepo_example/jobs/my_job.ex`):
   ```elixir
   defmodule MonorepoExample.Jobs.MyJob do
     use GoodJob.Job
     
     @impl GoodJob.Behaviour
     def perform(args) do
       # Your job logic here
       :ok
     end
   end
   ```

3. **Register handler** (`elixir/lib/monorepo_example/application.ex`):
   ```elixir
   # Configure external_jobs mapping in config/config.exs:
   # config :good_job, :config,
   #   external_jobs: %{
   #     "MonorepoExample::Jobs::MyJob" => MonorepoExample.Jobs.MyJob
   #   }
   ```

### Testing

```bash
# Rails tests
cd rails
bundle exec rspec

# Elixir tests
cd elixir
mix test
```

## Troubleshooting

### Jobs Not Processing

1. Check that both workers are running:
   ```bash
   # With Foreman
   foreman status
   
   # With Docker
   docker-compose ps
   ```

2. Verify database connection:
   ```bash
   # Rails
   cd rails && bundle exec rails db
   
   # Elixir
   cd elixir && mix ecto.migrate
   ```

3. Check queue names match:
   - Rails jobs should use `rb.default` queue (or other specific `rb.*` queue names)
   - Elixir jobs should use `ex.default` queue (or other specific `ex.*` queue names)

### Handler Not Found

1. **For Elixir jobs**: Verify handler is registered in `elixir/lib/monorepo_example/application.ex`
2. **For Zig jobs**: Verify handler is registered in `zig_worker/src/monorepo_example/jobs.zig`
3. Check job class name matches exactly (case-sensitive)
4. Ensure the module/class exists and implements the required interface

### Database Connection Issues

1. Verify PostgreSQL is running:
   ```bash
   pg_isready
   ```

2. Check database credentials in:
   - `rails/config/database.yml`
   - `elixir/config/config.exs`

3. Ensure database exists:
   ```bash
   createdb monorepo_example_development
   ```

## Environment Variables

### Rails

- `DATABASE_HOST`: PostgreSQL host (default: localhost)
- `DATABASE_PORT`: PostgreSQL port (default: 5432)
- `DATABASE_USER`: PostgreSQL user (default: postgres)
- `DATABASE_PASSWORD`: PostgreSQL password (default: postgres)
- `RAILS_ENV`: Rails environment (default: development)

### Elixir

- `DATABASE_HOST`: PostgreSQL host (default: localhost)
- `DATABASE_PORT`: PostgreSQL port (default: 5432)
- `DATABASE_USER`: PostgreSQL user (default: postgres)
- `DATABASE_PASSWORD`: PostgreSQL password (default: postgres)
- `DATABASE_NAME`: Database name (default: monorepo_example_development)
- `MIX_ENV`: Mix environment (default: dev)

## License

MIT

