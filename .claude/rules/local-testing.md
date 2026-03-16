# Local Testing

After making any code changes, rebuild and reinstall the app locally so the user can test immediately.

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
