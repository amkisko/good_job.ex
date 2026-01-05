# Quick Start Guide

## Prerequisites

- Ruby 3.2+
- Rails 8.0+
- Elixir 1.18+
- PostgreSQL 14+
- Docker & Docker Compose (optional, for containerized setup)
- Foreman (for local development): `gem install foreman`

## Option 1: Docker Compose (Easiest)

```bash
# Start all services
docker-compose up

# In another terminal, set up databases
docker-compose exec rails bundle exec rails db:create db:migrate
docker-compose exec elixir mix ecto.create mix ecto.migrate

# Test it
curl -X POST http://localhost:3000/jobs/enqueue?job_type=example
curl -X POST http://localhost:3000/jobs/enqueue?job_type=elixir
```

## Option 2: Local Development

### 1. Set up PostgreSQL

```bash
createdb monorepo_example_development
```

### 2. Set up Rails

```bash
cd rails
bundle install
bundle exec rails generate good_job:install
bundle exec rails db:create db:migrate
```

### 3. Set up Elixir

```bash
cd ../elixir
mix deps.get
mix good_job.install
mix ecto.create
mix ecto.migrate
```

### 4. Start with Foreman

```bash
# From monorepo_example directory
foreman start
```

This starts:
- Rails API on http://localhost:3000
- Rails worker (processes `rb.default` queue)
- Elixir worker (processes `ex.default` queue)

### 5. Test

```bash
# Enqueue a Ruby job
curl -X POST http://localhost:3000/jobs/enqueue?job_type=example&message="Hello"

# Enqueue an Elixir job
curl -X POST http://localhost:3000/jobs/enqueue?job_type=elixir&user_id=123&action=process
```

## Viewing Jobs

Visit http://localhost:3000/good_job to see the GoodJob dashboard.

## Troubleshooting

### Database connection errors

Make sure PostgreSQL is running:
```bash
pg_isready
```

### Jobs not processing

1. Check workers are running: `foreman status` or `docker-compose ps`
2. Verify database migrations ran successfully
3. Check logs: `foreman logs` or `docker-compose logs`

