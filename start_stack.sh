#!/usr/bin/env bash
# Start the local hackbot stack (run this each time you boot your machine).
#   bash start_stack.sh            # harness + discord bridge
#   bash start_stack.sh --caido    # also launch Caido GUI
set -uo pipefail
cd "$(dirname "$0")"
mkdir -p logs

BUN="$HOME/.bun/bin/bun"
PY="$HOME/.local/share/mdtools/venv/bin/python"

# --- harness ---
if curl -s -m 2 http://127.0.0.1:13337/api/health >/dev/null 2>&1; then
  echo "harness: already running"
else
  ( cd harness && set -a && . ../.env && set +a && PORT=13337 setsid "$BUN" run server.ts > ../logs/harness.log 2>&1 < /dev/null & )
  sleep 3
  curl -s -m 2 http://127.0.0.1:13337/api/health >/dev/null 2>&1 \
    && echo "harness: started -> http://127.0.0.1:13337" \
    || echo "harness: FAILED (see logs/harness.log)"
fi

# --- discord bridge ---
if pgrep -f 'discord_bot/bridge.py' >/dev/null 2>&1; then
  echo "discord bridge: already running"
else
  ( set -a && . ./.env && set +a && setsid "$PY" discord_bot/bridge.py > logs/bridge.log 2>&1 < /dev/null & )
  sleep 4
  grep -q 'Logged in as' logs/bridge.log 2>/dev/null \
    && echo "discord bridge: started" \
    || echo "discord bridge: check logs/bridge.log"
fi

# --- caido (optional) ---
if [ "${1:-}" = "--caido" ]; then
  if pgrep -f 'caido' >/dev/null 2>&1; then
    echo "caido: already running"
  elif command -v caido >/dev/null 2>&1; then
    setsid caido > logs/caido.log 2>&1 < /dev/null &
    echo "caido: launching (start the proxy in its UI)"
  else
    echo "caido: not installed"
  fi
fi

echo
echo "Dashboard : http://127.0.0.1:13337"
echo "Hunt      : python3 harness/scripts/orchestrate.py hunt <target> --budget 10"
echo "Logs      : logs/"
