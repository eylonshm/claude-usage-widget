#!/usr/bin/env bash
# install-pr-build.sh
# Downloads the latest CI-built DMG for a PR and installs it locally.
# Usage: scripts/install-pr-build.sh [PR_NUMBER]
#   If PR_NUMBER is omitted, it is inferred from the current branch.

set -euo pipefail

REPO="eylonshm/claude-usage-widget"

# ── 1. Resolve PR number ──────────────────────────────────────────────────────
PR="${1:-}"
if [ -z "$PR" ]; then
  PR=$(gh pr view --json number -q .number 2>/dev/null || true)
fi
if [ -z "$PR" ]; then
  echo "❌ Could not find a PR for the current branch."
  echo "   Check out a PR branch or pass the PR number: $0 <number>"
  exit 1
fi
echo "📋 PR #$PR"

BRANCH=$(gh pr view "$PR" --repo "$REPO" --json headRefName -q .headRefName)
echo "🌿 Branch: $BRANCH"

# ── 2. Find the latest workflow run for the PR workflow ───────────────────────
echo "🔍 Looking for CI run..."
RUN_ID=""
for i in $(seq 1 12); do            # retry up to ~60 s for the run to appear
  RUN_ID=$(gh run list \
    --repo "$REPO" \
    --branch "$BRANCH" \
    --workflow "pr.yml" \
    --limit 1 \
    --json databaseId \
    -q '.[0].databaseId // empty' 2>/dev/null || true)
  [ -n "$RUN_ID" ] && break
  echo "   waiting for run to appear... ($((i * 5))s)"
  sleep 5
done
if [ -z "$RUN_ID" ]; then
  echo "❌ No workflow run found for branch '$BRANCH'."
  echo "   Push a commit to trigger the PR workflow first."
  exit 1
fi
echo "👀 Run ID: $RUN_ID"

# ── 3. Wait for completion ────────────────────────────────────────────────────
echo "⏳ Waiting for CI to finish (this may take a few minutes)..."
gh run watch "$RUN_ID" --repo "$REPO" --exit-status

# ── 4. Download the DMG from the pre-release ─────────────────────────────────
TAG="pr-${PR}"
TMPDIR=$(mktemp -d)
echo "📥 Downloading DMG from release $TAG..."
gh release download "$TAG" \
  --repo "$REPO" \
  --pattern "*.dmg" \
  --dir "$TMPDIR" \
  --clobber

DMG=$(ls "$TMPDIR"/*.dmg | head -1)
echo "📦 Downloaded: $(basename "$DMG")"

# ── 5. Mount, install, launch ─────────────────────────────────────────────────
MOUNT=$(mktemp -d)
hdiutil attach "$DMG" -mountpoint "$MOUNT" -nobrowse -quiet

echo "🛑 Stopping running instance..."
pkill -x "Claude Usage" 2>/dev/null || true
sleep 2

echo "🗑️  Removing old installation..."
rm -rf "/Applications/Claude Usage.app"

echo "📂 Installing..."
cp -R "$MOUNT/Claude Usage.app" "/Applications/Claude Usage.app"
hdiutil detach "$MOUNT" -quiet

echo "🚀 Launching..."
open "/Applications/Claude Usage.app"

echo ""
echo "✅ Installed Claude Usage from PR #$PR build!"
echo "   To test widgets: right-click the desktop → Edit Widgets → search 'Claude'"
