# Cron Jobs Configuration

This document describes the cron jobs configured in the monorepo example for both Rails and Elixir sides.

## Rails Cron Jobs

Configured in `rails/config/initializers/good_job.rb`:

### 1. Ruby Scheduled Job
- **Key**: `ruby_scheduled`
- **Schedule**: Every 1 minute (`*/1 * * * *`)
- **Job Class**: `ScheduledRubyJob`
- **Queue**: `rb.default`
- **Description**: Scheduled Ruby job that runs every minute
- **Implementation**: `rails/app/jobs/scheduled_ruby_job.rb`

### 2. Elixir Scheduled Job
- **Key**: `elixir_scheduled`
- **Schedule**: Every 2 minutes (`*/2 * * * *`)
- **Job Class**: `ElixirProcessedJob`
- **Queue**: `ex.default` (processed by Elixir worker)
- **Description**: Scheduled Elixir job that runs every 2 minutes
- **Implementation**: `elixir/lib/monorepo_example/jobs/process_job.ex`

## Elixir Cron Jobs

Configured in `elixir/config/config.exs`:

### 1. Elixir Scheduled Job
- **Key**: `elixir_scheduled`
- **Schedule**: Every 3 minutes (`*/3 * * * *`)
- **Job Class**: `MonorepoExample.Jobs.ScheduledElixirJob`
- **Queue**: `ex.default`
- **Description**: Scheduled Elixir job that runs every 3 minutes
- **Implementation**: `elixir/lib/monorepo_example/jobs/scheduled_elixir_job.ex`

### 2. Ruby Scheduled Job
- **Key**: `ruby_scheduled_from_elixir`
- **Schedule**: Every 5 minutes (`*/5 * * * *`)
- **Job Class**: `MonorepoExample.Jobs.ScheduledRubyJob` (Elixir descriptor) → `ScheduledRubyJob` (Ruby class)
- **Queue**: `rb.default` (processed by Rails worker)
- **Description**: Scheduled Ruby job enqueued from Elixir cron using descriptor pattern
- **Implementation**: 
  - Elixir descriptor: `elixir/lib/monorepo_example/jobs/ruby_scheduled_wrapper_job.ex`
  - Ruby implementation: `rails/app/jobs/scheduled_ruby_job.rb`

## Schedule Summary

| Source | Job Type | Schedule | Queue | Worker |
|--------|----------|----------|-------|--------|
| Rails | Ruby | Every 1 min | `rb.default` | Rails |
| Rails | Elixir | Every 2 min | `ex.default` | Elixir |
| Elixir | Elixir | Every 3 min | `ex.default` | Elixir |
| Elixir | Ruby | Every 5 min | `rb.default` | Rails |

## Testing Cron Jobs

### View Cron Jobs in Rails Dashboard

Visit http://localhost:3000/good_job/cron to see all scheduled cron jobs.

### Check Cron Job Execution

```bash
# Check jobs in database
psql -h localhost -U postgres -d monorepo_example_development \
  -c "SELECT job_class, queue_name, cron_key, scheduled_at, finished_at 
      FROM good_jobs 
      WHERE cron_key IS NOT NULL 
      ORDER BY created_at DESC 
      LIMIT 10;"
```

### Manual Trigger (Rails)

```ruby
# In Rails console
GoodJob::CronEntry.find("ruby_scheduled").enqueue
GoodJob::CronEntry.find("elixir_scheduled").enqueue
```

### Manual Trigger (Elixir)

```elixir
# In IEx console
alias GoodJob.Cron.Entry
entry = Entry.new(key: "elixir_scheduled", cron: "*/3 * * * *", class: MonorepoExample.Jobs.ScheduledElixirJob, args: %{})
Entry.enqueue(entry, DateTime.utc_now())
```

## Notes

1. **Cross-Language Cron Jobs**: Both Rails and Elixir can schedule jobs for each other by using the appropriate queue names (`rb.default` or `ex.default`).

2. **Descriptor Pattern**: For cross-language cron jobs, use the descriptor pattern:
   - **Elixir → External**: Create an Elixir module using `GoodJob.ExternalJob` that references the external class name (see `MonorepoExample.Jobs.ScheduledRubyJob`)
   - **Ruby → Elixir**: Create a Ruby class using `include GoodJob::ActiveJobExtensions::ElixirJob` that references the Elixir module (see `ElixirProcessedJob`)
   - This ensures jobs are properly serialized and routed to the correct worker

3. **Queue Partitioning**: 
   - Jobs in `rb.default` queue are processed by Rails workers
   - Jobs in `ex.default` queue are processed by Elixir workers

4. **Cron Key Uniqueness**: Each cron job must have a unique key within the same application. Rails and Elixir can have the same key names since they run in separate processes.

5. **Graceful Restart**: After deployment, cron jobs will catch up on missed schedules within the `cron_graceful_restart_period` (if configured).

