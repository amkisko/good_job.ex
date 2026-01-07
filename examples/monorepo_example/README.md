# Monorepo Example: Rails + Elixir GoodJob

Working example demonstrating cross-language job processing using GoodJob.

## Quick Start

```bash
# Start all services
./start.sh

# Run migrations
cd rails && bundle exec rails db:create db:migrate && cd ..
cd elixir && mix ecto.create mix ecto.migrate && cd ..
```

Access:
- Rails: http://localhost:3000
- Elixir: http://localhost:4000

## Features

- **Cross-language jobs**: Rails enqueues jobs processed by Elixir workers
- **GlobalID support**: Rails objects serialized as GlobalID, deserialized in Elixir
- **Concurrency control**: Limits enforced across Ruby and Elixir workers
- **Web interface**: Buttons to test all features

## Testing

```bash
# Test GlobalID
cd rails && ruby test_globalid.rb
cd elixir && mix run test_globalid.exs

# Test concurrency
cd rails && ruby test_concurrency.rb
cd elixir && mix run test_concurrency.exs

# Test cross-language concurrency
cd rails && ruby test_cross_language_concurrency.rb
cd elixir && mix run test_cross_language_concurrency.exs
```

## Configuration

Jobs are mapped in `elixir/config/config.exs`:

```elixir
config :good_job,
  config: [
  external_jobs: %{
    "ElixirProcessedJob" => MonorepoExample.Jobs.ProcessJob,
      "GlobalidTestJob" => MonorepoExample.Jobs.GlobalidTestJob,
      "ConcurrencyTestJob" => MonorepoExample.Jobs.ConcurrencyTestJob,
      "CrossLanguageConcurrencyJob" => MonorepoExample.Jobs.CrossLanguageConcurrencyJob
    }
  ]
```

## Concurrency Keys

**Ruby**: Dynamic keys via lambda/proc
   ```ruby
good_job_control_concurrency_with(
  total_limit: 2,
  key: -> { "resource:#{arguments.first[:resource_id]}" }
)
```

**Elixir**: Pass key explicitly when enqueueing
   ```elixir
GoodJob.enqueue(MyJob, %{resource_id: 123}, concurrency_key: "resource:123")
```

Note: Elixir doesn't support dynamic key generation in config. Generate the key yourself and pass it in opts.
