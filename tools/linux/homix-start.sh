#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/opt/PFE"
AI_DIR="$BASE_DIR/backend/ai"
API_DIR="$BASE_DIR/backend/server"
RUN_DIR="$BASE_DIR/.run"
LOG_DIR="$BASE_DIR/.logs"
ENV_FILE="$BASE_DIR/tools/linux/homix.env"

mkdir -p "$RUN_DIR" "$LOG_DIR"

if [ -f "$ENV_FILE" ]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

start_ai() {
  if [ -f "$RUN_DIR/ai.pid" ] && kill -0 "$(cat "$RUN_DIR/ai.pid")" 2>/dev/null; then
    echo "AI already running with PID $(cat "$RUN_DIR/ai.pid")"
    return
  fi

  cd "$AI_DIR"
  nohup "$AI_DIR/.venv/bin/python" "$AI_DIR/app.py" > "$LOG_DIR/ai.log" 2>&1 &
  echo $! > "$RUN_DIR/ai.pid"
  echo "Started AI PID $(cat "$RUN_DIR/ai.pid")"
}

start_api() {
  if [ -f "$RUN_DIR/api.pid" ] && kill -0 "$(cat "$RUN_DIR/api.pid")" 2>/dev/null; then
    echo "API already running with PID $(cat "$RUN_DIR/api.pid")"
    return
  fi

  cd "$API_DIR"
  nohup /usr/bin/env node "$API_DIR/index.js" > "$LOG_DIR/api.log" 2>&1 &
  echo $! > "$RUN_DIR/api.pid"
  echo "Started API PID $(cat "$RUN_DIR/api.pid")"
}

wait_health() {
  local name="$1"
  local url="$2"
  local tries=25
  local i
  for i in $(seq 1 "$tries"); do
    if curl -fsS "$url" >/dev/null 2>&1; then
      echo "$name health OK: $url"
      return 0
    fi
    sleep 1
  done

  echo "$name health FAILED: $url"
  return 1
}

start_ai
start_api

wait_health "AI" "http://127.0.0.1:${FACE_PORT:-5000}/health"
wait_health "API" "http://127.0.0.1:${PORT:-3000}/health"

echo "All services started"
