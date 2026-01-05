#!/bin/bash
set -e

echo "Stopping Monorepo Example processes gracefully..."

# Find foreman process
FOREMAN_PID=$(pgrep -f "foreman start" | head -1)

if [ -n "$FOREMAN_PID" ]; then
  echo "Found foreman process (PID: $FOREMAN_PID), sending SIGTERM..."
  
  # Send SIGTERM to foreman (graceful shutdown)
  kill -TERM "$FOREMAN_PID" 2>/dev/null || true
  
  # Wait up to 10 seconds for graceful shutdown
  for i in {1..10}; do
    if ! ps -p "$FOREMAN_PID" > /dev/null 2>&1; then
      echo "Foreman stopped gracefully."
      break
    fi
    sleep 1
  done
  
  # If still running, force kill
  if ps -p "$FOREMAN_PID" > /dev/null 2>&1; then
    echo "Foreman did not stop gracefully, forcing termination..."
    kill -9 "$FOREMAN_PID" 2>/dev/null || true
  fi
else
  echo "No foreman process found."
fi

# Wait a moment for child processes to exit
sleep 2

# Run cleanup to handle any remaining processes
echo ""
echo "Running cleanup for any remaining processes..."
"$(dirname "$0")/cleanup.sh"

