#!/usr/bin/env bash
# Pull the latest Claude-BugHunter upstream into this fork and push.
# Run periodically (or rely on .github/workflows/sync-upstream.yml).
set -euo pipefail
cd "$(dirname "$0")/.."

if ! git remote get-url upstream >/dev/null 2>&1; then
  git remote add upstream https://github.com/elementalsouls/Claude-BugHunter.git
fi
git fetch upstream
git merge upstream/main --no-edit
git push origin main
echo "Fork synced with upstream."
