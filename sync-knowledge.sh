#!/bin/bash
# sync-knowledge.sh
#
# Commit & push all subrepos, then update submodule pointers in the parent repo.
#
# Usage:
#   bash sync-knowledge.sh "daily log 2026.6.26 - reviewed K8s scheduling"
#   bash sync-knowledge.sh                                      # uses "sync" as fallback message
#
# This avoids the two-step friction of submodules:
#   (cd subrepos/daily-record && git add ... && git push)
#   git add subrepos/daily-record && git commit && git push
#
# One command does it all.

set -e

MSG="${*:-sync}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== Syncing all subrepos ==="
for dir in subrepos/*/; do
  name="$(basename "$dir")"
  echo ""
  echo "--- $name ---"
  (cd "$dir" && git add -A && git commit --allow-empty -m "$MSG" && git push) || echo "  (nothing to commit)"
done

echo ""
echo "=== Updating parent repo submodule pointers ==="
git add subrepos/
git commit --allow-empty -m "update knowledge submodules: $MSG" || true
git push

echo ""
echo "Done. All subrepos pushed."
