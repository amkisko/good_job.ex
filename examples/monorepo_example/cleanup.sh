#!/bin/bash
# Don't use set -e here because we expect some kill commands to fail
# when processes don't exist

echo "Cleaning up Monorepo Example processes and files..."

# Function to kill process tree (parent and all children)
kill_tree() {
  local pid=$1
  if [ -z "$pid" ]; then
    return
  fi
  
  # Kill all children first
  for child in $(pgrep -P "$pid" 2>/dev/null); do
    kill_tree "$child"
  done
  
  # Kill the process itself
  kill -9 "$pid" 2>/dev/null || true
}

# Function to find and kill zombie processes' parents
cleanup_zombies() {
  echo "Checking for zombie processes..."
  local zombies=$(ps aux | awk '$8 ~ /^Z/ { print $2, $3 }' | grep -v "^$$" || true)
  
  if [ -n "$zombies" ]; then
    echo "Found zombie processes, cleaning up..."
    echo "$zombies" | while read -r zpid ppid; do
      if [ -n "$ppid" ] && [ "$ppid" != "1" ]; then
        echo "  Killing parent process $ppid of zombie $zpid"
        kill_tree "$ppid" 2>/dev/null || true
      fi
    done
  fi
}

# Kill processes on port 3000 (Rails) and their children
if lsof -ti:3000 > /dev/null 2>&1; then
  echo "Killing processes on port 3000 (Rails)..."
  lsof -ti:3000 | while read -r pid; do
    kill_tree "$pid" 2>/dev/null || true
  done
  sleep 1
fi

# Kill processes on port 4000 (Elixir web) and their children
if lsof -ti:4000 > /dev/null 2>&1; then
  echo "Killing processes on port 4000 (Elixir web)..."
  lsof -ti:4000 | while read -r pid; do
    kill_tree "$pid" 2>/dev/null || true
  done
  sleep 1
fi

# Remove Rails PID file
RAILS_PID_FILE="rails/tmp/pids/server.pid"
if [ -f "$RAILS_PID_FILE" ]; then
  PID=$(cat "$RAILS_PID_FILE" 2>/dev/null || echo "")
  if [ -n "$PID" ]; then
    # Check if process is still running
    if ps -p "$PID" > /dev/null 2>&1; then
      echo "Killing Rails server process tree (PID: $PID)..."
      kill_tree "$PID" 2>/dev/null || true
    fi
  fi
  echo "Removing Rails PID file..."
  rm -f "$RAILS_PID_FILE"
fi

# Kill all foreman processes and their children
if pgrep -f "foreman" > /dev/null 2>&1; then
  echo "Killing foreman processes and their children..."
  pgrep -f "foreman" | while read -r pid; do
    kill_tree "$pid" 2>/dev/null || true
  done
  sleep 1
fi

# Kill all mix processes (phx.server, run --no-halt, etc.) and their children
if pgrep -f "mix " > /dev/null 2>&1; then
  echo "Killing mix processes and their children..."
  pgrep -f "mix " | while read -r pid; do
    kill_tree "$pid" 2>/dev/null || true
  done
  sleep 1
fi

# Kill all beam.smp processes (Erlang/Elixir) that are related to this project
if pgrep -f "beam.smp" > /dev/null 2>&1; then
  echo "Killing Erlang/Elixir beam processes..."
  pgrep -f "beam.smp" | while read -r pid; do
    # Check if it's related to our project directory
    if ps -p "$pid" -o command= | grep -q "monorepo_example"; then
      echo "  Killing beam process $pid"
      kill_tree "$pid" 2>/dev/null || true
    fi
  done
  sleep 1
fi

# Kill all good_job processes and their children
if pgrep -f "good_job" > /dev/null 2>&1; then
  echo "Killing GoodJob processes and their children..."
  pgrep -f "good_job" | while read -r pid; do
    kill_tree "$pid" 2>/dev/null || true
  done
  sleep 1
fi

# Kill file_system listeners (mac_listener processes)
if pgrep -f "mac_listener" > /dev/null 2>&1; then
  echo "Killing file system listener processes..."
  pgrep -f "mac_listener" | while read -r pid; do
    if ps -p "$pid" -o command= | grep -q "monorepo_example"; then
      echo "  Killing mac_listener process $pid"
      kill -9 "$pid" 2>/dev/null || true
    fi
  done
  sleep 1
fi

# Clean up zombie processes
cleanup_zombies

# Final cleanup: kill any remaining processes in the project directory
echo "Performing final cleanup..."
cd "$(dirname "$0")" || exit 1

# Wait a moment for processes to fully terminate
sleep 2

# Check for any remaining processes
REMAINING=$(pgrep -f "monorepo_example" 2>/dev/null | wc -l | tr -d ' ')
if [ "$REMAINING" -gt 0 ]; then
  echo "Warning: $REMAINING processes still running. Attempting final cleanup..."
  pgrep -f "monorepo_example" | while read -r pid; do
    # Skip this script itself
    if [ "$pid" != "$$" ]; then
      kill_tree "$pid" 2>/dev/null || true
    fi
  done
  sleep 1
fi

echo ""
echo "Cleanup complete!"
echo ""
echo "You can now start the application with:"
echo "  foreman start"

