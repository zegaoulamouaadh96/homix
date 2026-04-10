#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/opt/PFE"
RUN_DIR="$BASE_DIR/.run"

stop_by_pid_file() {
  local name="$1"
  local pid_file="$2"

  if [ ! -f "$pid_file" ]; then
    echo "$name is not running (no pid file)"
    return
  fi

  local pid
  pid="$(cat "$pid_file")"

  if kill -0 "$pid" 2>/dev/null; then
    kill "$pid" || true
    for _ in $(seq 1 10); do
      if ! kill -0 "$pid" 2>/dev/null; then
        break
      fi
      sleep 1
    done
    if kill -0 "$pid" 2>/dev/null; then
      kill -9 "$pid" || true
    fi
    echo "Stopped $name PID $pid"
  else
    echo "$name PID $pid not active"
  fi

  rm -f "$pid_file"
}

stop_by_pid_file "API" "$RUN_DIR/api.pid"
stop_by_pid_file "AI" "$RUN_DIR/ai.pid"
