FROM elixir:1.18-slim

# Install dependencies
RUN apt-get update -qq && apt-get install -y \
  build-essential \
  libpq-dev \
  postgresql-client \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install hex and rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Copy mix files
COPY mix.exs mix.lock* ./

# Install dependencies (good_job.ex will be mounted as volume)
RUN mix deps.get || true

# Copy application code
COPY . .

# Compile application
RUN mix compile || mix deps.get && mix compile

# Default command (can be overridden in docker-compose)
CMD ["mix", "run", "--no-halt"]

