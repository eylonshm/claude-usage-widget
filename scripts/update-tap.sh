#!/usr/bin/env bash
set -euo pipefail

VERSION="$1"
SHA256="$2"
TAP_TOKEN="$3"

CASK=$(cat <<'EOF'
cask "claude-usage-widget" do
  version "VERSION_PLACEHOLDER"
  sha256 "SHA256_PLACEHOLDER"

  url "https://github.com/eylonshm/claude-usage-widget/releases/download/v#{version}/ClaudeUsage-#{version}.dmg"
  name "Claude Usage Widget"
  desc "macOS menu bar app and desktop widgets for monitoring Claude Code usage and quota"
  homepage "https://github.com/eylonshm/claude-usage-widget"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: ">= :sonoma"

  app "Claude Usage.app"

  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-cr", "#{appdir}/Claude Usage.app"],
                   sudo: false
  end

  zap trash: [
    "~/Library/Preferences/com.claudeusage.app.plist",
    "~/Library/Application Support/Claude Usage",
    "~/Library/Caches/com.claudeusage.app",
  ]
end
EOF
)

CASK="${CASK/VERSION_PLACEHOLDER/$VERSION}"
CASK="${CASK/SHA256_PLACEHOLDER/$SHA256}"

ENCODED=$(printf '%s' "$CASK" | base64)
CURRENT_SHA=$(curl -sf -H "Authorization: token $TAP_TOKEN" \
  "https://api.github.com/repos/eylonshm/homebrew-tap/contents/Casks/claude-usage-widget.rb" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['sha'])")

jq -n \
  --arg message "chore: bump claude-usage-widget to v${VERSION}" \
  --arg sha "$CURRENT_SHA" \
  --arg content "$ENCODED" \
  '{message: $message, sha: $sha, content: $content}' \
| curl -sf -X PUT \
  -H "Authorization: token $TAP_TOKEN" \
  -H "Content-Type: application/json" \
  "https://api.github.com/repos/eylonshm/homebrew-tap/contents/Casks/claude-usage-widget.rb" \
  -d @-

echo "Tap updated to v${VERSION}"
