# Local Testing

After making any code changes, rebuild and reinstall the app locally so the user can test immediately. Always kill the running instance and use `rm -rf` before copying — never use a shortcut install.

```bash
xcodegen generate

xcodebuild \
  -project ClaudeUsage.xcodeproj \
  -scheme ClaudeUsage \
  -configuration Release \
  build \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_ALLOWED=NO \
  CONFIGURATION_BUILD_DIR="$(pwd)/build"

mkdir -p "build/Claude Usage.app/Contents/PlugIns"
cp -R "build/ClaudeUsageWidgetExtension.appex" "build/Claude Usage.app/Contents/PlugIns/"
mkdir -p "build/Claude Usage.app/Contents/Resources"
cp ClaudeUsage/Resources/fetch-quota.sh "build/Claude Usage.app/Contents/Resources/"
chmod +x "build/Claude Usage.app/Contents/Resources/fetch-quota.sh"

pkill -x "Claude Usage" 2>/dev/null || true
sleep 2
rm -rf "/Applications/Claude Usage.app"
cp -R "build/Claude Usage.app" "/Applications/Claude Usage.app"
open "/Applications/Claude Usage.app"
```

Note: always `rm -rf` the old app before copying — a plain `cp -R` over an existing `.app` will silently leave stale files.

**Never push changes before the user confirms the locally installed app is working correctly.**

## Testing via PR build (for widget / signing-dependent features)

Some features (e.g. widget gallery registration) require a properly assembled DMG to test. After creating a PR, use:

```bash
scripts/install-pr-build.sh          # auto-detects PR from current branch
scripts/install-pr-build.sh <number> # or pass PR number explicitly
```

The script waits for the CI workflow to finish, downloads the DMG from the GitHub pre-release, and installs it — same flow as a real user download. Run this after every push that needs PR-level testing.

**When to use PR build instead of local build:**

- Any change touching the widget extension (WidgetKit registration, widget UI, widget data)
- Any signing-dependent feature
- Whenever the user says "I can't see the widget in Edit Widgets" — this means the local unsigned build was used; switch to PR build

In these cases: push the branch, open a PR if one doesn't exist, then run `scripts/install-pr-build.sh` automatically — do not wait for the user to ask. The script blocks until CI finishes and installs the signed build.
