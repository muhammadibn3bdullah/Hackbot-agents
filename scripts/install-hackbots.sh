#!/usr/bin/env bash
# Install the added Hackbots control plane (harness + Discord bridge + agents).
# The 88 skills (83 Claude-BugHunter + 5 hackbots) are installed by the upstream
# scripts/install.sh; this script wires the extra control-plane pieces.
set -euo pipefail
cd "$(dirname "$0")/.."
REPO="$PWD"

mkdir -p ~/.config/opencode/agents ~/.claude/agents
for f in agents/*.md; do
  n=$(basename "$f")
  for base in ~/.config/opencode/agents ~/.claude/agents; do
    if [ ! -e "$base/$n" ] && [ ! -L "$base/$n" ]; then
      ln -s "$REPO/agents/$n" "$base/$n"
      echo "linked agent $n -> $base"
    fi
  done
done

BUN="$(command -v bun || true)"
[ -n "$BUN" ] || BUN="$HOME/.bun/bin/bun"
if [ -x "$BUN" ]; then
  ( cd harness && "$BUN" install )
else
  echo "NOTE: Bun not found. Install from https://bun.sh then: cd harness && bun install"
fi

[ -f .env ] || cp .env.example .env

echo
echo "Control plane installed. Next:"
echo "  1. edit .env (API keys, Discord token/IDs, webhook)"
echo "  2. bash start_stack.sh"
echo "  3. python3 harness/scripts/orchestrate.py hunt <target> --budget 10"
