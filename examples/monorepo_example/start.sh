#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "Starting Monorepo Example..."

# Check prerequisites
command -v foreman >/dev/null 2>&1 || { 
  echo "Error: foreman is required but not installed." >&2
  echo "Install it with: gem install foreman" >&2
  exit 1
}

command -v ruby >/dev/null 2>&1 || { 
  echo "Error: Ruby is required but not installed." >&2
  exit 1
}

command -v mix >/dev/null 2>&1 || { 
  echo "Error: Elixir is required but not installed." >&2
  exit 1
}

# Check if foreman is already running
FOREMAN_PID=$(pgrep -f "foreman start" | head -1)
if [ -n "$FOREMAN_PID" ]; then
  echo "Warning: Foreman is already running (PID: $FOREMAN_PID)"
  echo "Please stop it first using: ./stop.sh"
  echo ""
  read -p "Would you like to stop it now? (y/N) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    ./stop.sh
    sleep 2
  else
    echo "Aborting. Please stop foreman manually and try again."
    exit 1
  fi
fi

# Check for port conflicts
PORTS_IN_USE=()

if lsof -ti:3000 > /dev/null 2>&1; then
  PORTS_IN_USE+=("3000 (Rails)")
fi

if lsof -ti:4000 > /dev/null 2>&1; then
  PORTS_IN_USE+=("4000 (Elixir web)")
fi

if [ ${#PORTS_IN_USE[@]} -gt 0 ]; then
  echo "Warning: The following ports are already in use:"
  for port in "${PORTS_IN_USE[@]}"; do
    echo "  - Port $port"
  done
  echo ""
  read -p "Would you like to clean up these ports? (y/N) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    ./cleanup.sh
    sleep 2
  else
    echo "Warning: Port conflicts may prevent services from starting."
    echo "You can clean up later with: ./cleanup.sh"
  fi
fi

# Check if Procfile exists
if [ ! -f "Procfile" ]; then
  echo "Error: Procfile not found in $SCRIPT_DIR" >&2
  exit 1
fi

# Check if Rails directory exists and has dependencies
if [ ! -d "rails" ]; then
  echo "Error: Rails directory not found. Have you run setup.sh?" >&2
  exit 1
fi

if [ ! -f "rails/Gemfile.lock" ]; then
  echo "Warning: Rails dependencies may not be installed."
  echo "Run: cd rails && bundle install"
fi

# Check if Elixir directory exists and has dependencies
if [ ! -d "elixir" ]; then
  echo "Error: Elixir directory not found. Have you run setup.sh?" >&2
  exit 1
fi

if [ ! -f "elixir/mix.lock" ]; then
  echo "Warning: Elixir dependencies may not be installed."
  echo "Run: cd elixir && mix deps.get"
fi

# Check database connection (optional, non-fatal)
if command -v psql >/dev/null 2>&1; then
  if ! psql -lqt -d monorepo_example_development >/dev/null 2>&1; then
    echo "Warning: Database 'monorepo_example_development' may not exist."
    echo "Run: createdb monorepo_example_development"
  fi
fi

echo ""
echo "Starting services with foreman..."
echo "Press Ctrl+C to stop all services"
echo ""

# Start foreman
foreman start

