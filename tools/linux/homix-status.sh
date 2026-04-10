#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/opt/PFE"
RUN_DIR="$BASE_DIR/.run"

show_pid() {
  local name="$1"
  local pid_file="$2"
  if [ -f "$pid_file" ]; then
    local pid
    pid="$(cat "$pid_file")"
    if kill -0 "$pid" 2>/dev/null; then
      echo "$name running PID $pid"
    else
      echo "$name stale pid file ($pid)"
    fi
  else
    echo "$name not running"
  fi
}

show_pid "API" "$RUN_DIR/api.pid"
show_pid "AI" "$RUN_DIR/ai.pid"

echo ""
echo "Ports"
ss -ltnp | egrep ':3000|:5000|:1883' || true

echo ""
echo "Health"
curl -sS http://127.0.0.1:3000/health || true
echo ""
curl -sS http://127.0.0.1:5000/health || true
echo ""
