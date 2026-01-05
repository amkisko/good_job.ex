#!/bin/bash
set -e

echo "Setting up Monorepo Example..."

# Check prerequisites
command -v ruby >/dev/null 2>&1 || { echo "Ruby is required but not installed. Aborting." >&2; exit 1; }
command -v mix >/dev/null 2>&1 || { echo "Elixir is required but not installed. Aborting." >&2; exit 1; }
command -v psql >/dev/null 2>&1 || { echo "PostgreSQL is required but not installed. Aborting." >&2; exit 1; }

# Create database
echo "Creating database..."
createdb monorepo_example_development 2>/dev/null || echo "Database may already exist"

# Setup Rails
echo "Setting up Rails..."
cd rails
bundle install
bundle exec rails generate good_job:install
bundle exec rails db:setup
cd ..

# Setup Elixir
echo "Setting up Elixir..."
cd elixir
mix deps.get
mix good_job.install
mix ecto.setup
cd ..

echo "Setup complete!"
echo ""
echo "To start the application:"
echo "  ./start.sh"
echo ""
echo "Or start foreman directly:"
echo "  foreman start"
echo ""
echo "Or with Docker:"
echo "  docker-compose up"

