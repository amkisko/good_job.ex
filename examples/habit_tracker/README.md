# Habit Tracker - GoodJob Example Application

A comprehensive example application showcasing all features of GoodJob, built with Phoenix LiveView, Phlex, StyleCapsule, and Tailwind CSS.

## Overview

This is a **kid habit tracker and trainer** application that demonstrates GoodJob in a real-world scenario.

**Key Features:**
- **Zero-config startup**: Database seeds and GoodJob processors start automatically
- **Production-ready**: Full example with proper error handling and monitoring

**Application Features:**
- **Daily routines tracking**: Washing, walking, going to bed, chores
- **Job processing**: Analytics calculation, streak tracking, points calculation
- **Cron jobs**: Daily task updates, streak calculations, points calculations, data sync
- **Mock integrations**: External API synchronization
- **Real-time UI**: Phoenix LiveView with Phlex components

## Features Demonstrated

### GoodJob Features

1. **Job Enqueueing**: Manual and automatic job creation
2. **Cron Jobs**: Scheduled jobs for daily operations
3. **Job Queues**: Different queues for different job types
4. **Job Priorities**: Priority-based job execution
5. **Job Retries**: Automatic retry with exponential backoff
6. **Job Timeouts**: Timeout handling for long-running jobs
7. **Job Monitoring**: Real-time job status monitoring
8. **Batch Operations**: Grouping related jobs
9. **Concurrency Controls**: Limiting concurrent job execution

### Application Features

- **Habit Management**: Create and manage daily habits
- **Task Tracking**: Track daily task completions
- **Streak Calculation**: Automatic streak tracking
- **Points System**: Points earned for completed tasks
- **Analytics**: Completion rates and statistics
- **Real-time Updates**: LiveView updates for job status

## Setup

### Prerequisites

- Elixir 1.18+
- PostgreSQL 12+
- Node.js (for Tailwind CSS)

### Installation

1. **Clone and navigate to the example:**

```bash
cd good_job.ex/examples/habit_tracker
```

2. **Install dependencies:**

```bash
mix deps.get
```

3. **Set up the database (one-time setup):**

```bash
# Install GoodJob migrations (creates migration file)
mix good_job.install

# Create database and run migrations
mix ecto.setup
```

Or manually:
```bash
# Install GoodJob migrations (creates migration file)
mix good_job.install

# Create database
mix ecto.create

# Run migrations (includes both habit_tracker and GoodJob migrations)
mix ecto.migrate

# Seed initial data (optional - will auto-seed on first boot)
mix run priv/repo/seeds.exs
```

4. **Build assets:**

```bash
mix assets.build
```

5. **Start the server:**

```bash
mix phx.server
```

Visit [http://localhost:4000](http://localhost:4000) to see the application.

### Automatic Startup Features

The application automatically:

- **Seeds the database** on first boot if no habits exist
- **Starts GoodJob processors** automatically - no additional commands needed
- **Runs cron jobs** as configured (daily task updates, streak calculations, etc.)

When you start the server, you'll see messages like:
- `✅ Database seeded successfully on startup!` (on first run)
- `ℹ️  Database already has X habit(s), skipping seed.` (on subsequent runs)

GoodJob will automatically start processing jobs as soon as the application boots. You can monitor job execution in real-time on the `/jobs` page.

## Database Setup

The application uses PostgreSQL. Make sure PostgreSQL is running and create a database:

```bash
createdb habit_tracker_dev
```

Or update the database configuration in `config/config.exs` to match your PostgreSQL setup.

## Application Structure

```
lib/
├── habit_tracker/
│   ├── application.ex          # Application supervisor
│   ├── repo.ex                  # Ecto repository
│   ├── schemas/                 # Database schemas
│   │   ├── habit.ex
│   │   ├── task.ex
│   │   ├── completion.ex
│   │   ├── streak.ex
│   │   ├── point_record.ex
│   │   └── analytics.ex
│   └── jobs/                    # GoodJob jobs
│       ├── daily_task_update_job.ex
│       ├── streak_calculation_job.ex
│       ├── points_calculation_job.ex
│       ├── analytics_job.ex
│       ├── data_sync_job.ex
│       └── task_completion_job.ex
└── habit_tracker_web/
    ├── components/              # Phlex components
    │   └── habit_card.ex
    ├── live/                    # LiveView pages
    │   ├── dashboard_live.ex
    │   ├── habits_live.ex
    │   ├── analytics_live.ex
    │   └── jobs_live.ex
    ├── layouts/                 # Layout templates
    ├── router.ex
    └── endpoint.ex
```

## GoodJob Configuration

The application is configured with GoodJob in `config/config.exs`:

```elixir
config :good_job,
  repo: HabitTracker.Repo,
  execution_mode: :async,
  max_processes: 5,
  poll_interval: 30,
  queues: "*",
  enable_listen_notify: true,
  enable_cron: true,
  cron: [
    daily_task_update: [
      cron: "0 0 * * *",  # Every day at midnight
      class: HabitTracker.Jobs.DailyTaskUpdateJob
    ],
    streak_calculation: [
      cron: "0 1 * * *",  # Every day at 1 AM
      class: HabitTracker.Jobs.StreakCalculationJob
    ],
    points_calculation: [
      cron: "0 2 * * *",  # Every day at 2 AM
      class: HabitTracker.Jobs.PointsCalculationJob
    ],
    data_sync: [
      cron: "*/30 * * * *",  # Every 30 minutes
      class: HabitTracker.Jobs.DataSyncJob
    ]
  ]
```

## Jobs Overview

### DailyTaskUpdateJob

Creates daily tasks for all enabled habits. Runs at midnight via cron.

**Usage:**
```elixir
HabitTracker.Jobs.DailyTaskUpdateJob.perform_later(%{date: Date.utc_today()})
```

### StreakCalculationJob

Calculates streaks for all habits based on task completions. Runs daily at 1 AM.

**Usage:**
```elixir
HabitTracker.Jobs.StreakCalculationJob.perform_later(%{})
```

### PointsCalculationJob

Calculates total points, daily points, weekly points, and monthly points. Runs daily at 2 AM.

**Usage:**
```elixir
HabitTracker.Jobs.PointsCalculationJob.perform_later(%{})
```

### AnalyticsJob

Calculates analytics (completion rates, trends, etc.). Can be enqueued manually or via cron.

**Usage:**
```elixir
HabitTracker.Jobs.AnalyticsJob.perform_later(%{
  period: "daily",
  period_start: Date.utc_today(),
  period_end: Date.utc_today()
})
```

### DataSyncJob

Mock integration job that simulates syncing data with an external API. Runs every 30 minutes.

**Usage:**
```elixir
HabitTracker.Jobs.DataSyncJob.perform_later(%{sync_type: "completions"})
```

### TaskCompletionJob

Handles task completion (marks task as completed, creates completion record, awards points).

**Usage:**
```elixir
HabitTracker.Jobs.TaskCompletionJob.perform_later(%{task_id: task_id})
```

## Pages

### Dashboard (`/`)

- Shows today's habits and tasks
- Displays point statistics (total, today, this week, this month)
- Allows completing tasks (enqueues TaskCompletionJob)

### Habits (`/habits`)

- Lists all habits with their categories and points
- Shows habit status (enabled/disabled)

### Analytics (`/analytics`)

- Displays analytics records
- Allows triggering analytics calculations for different periods
- Shows completion rates and statistics

### Jobs (`/jobs`)

- Real-time monitoring of GoodJob jobs
- Shows job statistics (available, executing, completed, retryable, discarded)
- Displays recent jobs with their status

## Development

### Running Tests

```bash
mix test
```

### Code Formatting

```bash
mix format
```

### Building Assets

```bash
mix assets.build
```

### Watching Assets (Development)

Assets are automatically watched when running `mix phx.server` in development mode.

## Production Deployment

1. Set environment variables for database connection
2. Run migrations: `mix ecto.migrate`
3. Build assets: `mix assets.deploy`
4. Start the application with your preferred deployment method

## Learn More

- [GoodJob Documentation](../../README.md)
- [Phoenix LiveView](https://hexdocs.pm/phoenix_live_view/)
- [Phlex](https://hexdocs.pm/phlex/)
- [StyleCapsule](https://hexdocs.pm/style_capsule/)
- [Tailwind CSS](https://tailwindcss.com/)

## License

This example application is provided as-is for demonstration purposes.
