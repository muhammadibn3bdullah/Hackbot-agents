#!/usr/bin/env bash
# Start the local hackbot stack (Linux / macOS). Run each time you boot.
#   bash start_stack.sh            # harness + discord bridge
#   bash start_stack.sh --caido    # also launch Caido GUI
# Windows: use start_stack.ps1 instead.
set -uo pipefail
cd "$(dirname "$0")"
mkdir -p logs

BUN="$(command -v bun || true)"
[ -n "$BUN" ] || BUN="$HOME/.bun/bin/bun"
PY="$(command -v python3 || command -v python || echo python3)"

have() { command -v "$1" >/dev/null 2>&1; }
health() {
  if have curl; then curl -s -m 2 http://127.0.0.1:13337/api/health >/dev/null 2>&1
  elif have wget; then wget -q -T 2 -O /dev/null http://127.0.0.1:13337/api/health 2>/dev/null
  else return 1; fi
}

# --- harness ---
if health; then
  echo "harness: already running"
else
  ( cd harness && set -a && . ../.env && set +a && PORT=13337 nohup "$BUN" run server.ts > ../logs/harness.log 2>&1 & )
  sleep 3
  if health; then echo "harness: started -> http://127.0.0.1:13337"; else echo "harness: FAILED (see logs/harness.log)"; fi
fi

# --- discord bridge ---
if pgrep -f 'discord_bot/bridge.py' >/dev/null 2>&1; then
  echo "discord bridge: already running"
else
  ( set -a && . ./.env && set +a && nohup "$PY" discord_bot/bridge.py > logs/bridge.log 2>&1 & )
  sleep 4
  if grep -q 'Logged in as' logs/bridge.log 2>/dev/null; then echo "discord bridge: started"; else echo "discord bridge: check logs/bridge.log"; fi
fi

# --- caido (optional) ---
if [ "${1:-}" = "--caido" ]; then
  if pgrep -f 'caido' >/dev/null 2>&1; then
    echo "caido: already running"
  elif have caido; then
    nohup caido > logs/caido.log 2>&1 &
    echo "caido: launching (start the proxy in its UI)"
  else
    echo "caido: not installed"
  fi
fi

echo
echo "Dashboard : http://127.0.0.1:13337"
echo "Hunt      : $PY harness/scripts/orchestrate.py hunt <target> --budget 10"
echo "Logs      : logs/"
