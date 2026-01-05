# Database Setup Verification

## Shared Database Configuration

Both Rails and Elixir applications use the **same PostgreSQL database** to enable cross-language job processing.

### Database Name
- **Development**: `monorepo_example_development`
- **Test**: `monorepo_example_test`
- **Production**: `monorepo_example_production`

### Connection Settings

Both applications use the same connection parameters:

```bash
DATABASE_HOST=localhost
DATABASE_PORT=5432
DATABASE_USER=postgres
DATABASE_PASSWORD=postgres
DATABASE_NAME=monorepo_example_development
```

### Rails Configuration

**File**: `rails/config/database.yml`

```yaml
development:
  adapter: postgresql
  database: monorepo_example_development
  host: localhost
  port: 5432
  username: postgres
  password: postgres
```

### Elixir Configuration

**File**: `elixir/config/config.exs`

```elixir
config :monorepo_example_worker, MonorepoExample.Repo,
  hostname: "localhost",
  port: 5432,
  username: "postgres",
  password: "postgres",
  database: "monorepo_example_development"
```

## GoodJob Tables

The following tables are created by Rails migrations and shared by both applications:

- `good_jobs` - Main job queue table
- `good_job_batches` - Batch job tracking
- `good_job_executions` - Job execution history
- `good_job_processes` - Worker process tracking
- `good_job_settings` - Configuration settings

## Verification

Run the verification script to confirm both applications can connect:

```bash
elixir verify_database.exs
```

Or verify manually:

```bash
# From Rails
cd rails && bundle exec rails runner "puts ActiveRecord::Base.connection.current_database"

# From Elixir (when compiled)
cd elixir && mix run -e "IO.inspect(MonorepoExample.Repo.config()[:database])"
```

## Important Notes

1. **Single Source of Truth**: Rails creates the database and migrations. Elixir connects to the same database.

2. **No Duplicate Migrations**: Elixir should NOT run its own migrations for GoodJob tables. The tables are created by Rails.

3. **Queue Partitioning**: 
   - Rails processes `rb.default` queue (or other specific `rb.*` queue names)
   - Elixir processes `ex.default` queue (or other specific `ex.*` queue names)
   - Both read from the same `good_jobs` table
   - Note: Ruby GoodJob doesn't support wildcard patterns, so use specific queue names

4. **Cross-Language Jobs**: Jobs enqueued by Rails can be processed by Elixir (and vice versa) because they share the same database.

