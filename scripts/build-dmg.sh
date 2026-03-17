#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
DMG_DIR="$PROJECT_DIR/dist"
APP_NAME="Claude Usage"
DMG_NAME="ClaudeUsage"
VERSION="${1:-1.0.0}"
KEYCHAIN_PROFILE="ClaudeUsage"  # Created via: xcrun notarytool store-credentials "ClaudeUsage"

echo "==> Cleaning previous builds..."
rm -rf "$BUILD_DIR" "$DMG_DIR"
mkdir -p "$BUILD_DIR" "$DMG_DIR"

echo "==> Generating Xcode project..."
cd "$PROJECT_DIR"
xcodegen generate

echo "==> Building Release (signed)..."
xcodebuild \
    -project ClaudeUsage.xcodeproj \
    -scheme ClaudeUsage \
    -configuration Release \
    build \
    CONFIGURATION_BUILD_DIR="$BUILD_DIR" \
    2>&1 | grep -E "BUILD|error:" || true

if [ ! -d "$BUILD_DIR/$APP_NAME.app" ]; then
    echo "ERROR: Build failed — $APP_NAME.app not found"
    exit 1
fi

echo "==> Embedding widget extension..."
mkdir -p "$BUILD_DIR/$APP_NAME.app/Contents/PlugIns"
cp -R "$BUILD_DIR/ClaudeUsageWidgetExtension.appex" "$BUILD_DIR/$APP_NAME.app/Contents/PlugIns/"

echo "==> Bundling resources..."
mkdir -p "$BUILD_DIR/$APP_NAME.app/Contents/Resources"
cp "$PROJECT_DIR/ClaudeUsage/Resources/fetch-quota.sh" "$BUILD_DIR/$APP_NAME.app/Contents/Resources/"
chmod +x "$BUILD_DIR/$APP_NAME.app/Contents/Resources/fetch-quota.sh"

echo "==> Verifying code signature..."
codesign --verify --deep --strict "$BUILD_DIR/$APP_NAME.app"
codesign -dv --verbose=4 "$BUILD_DIR/$APP_NAME.app" 2>&1 | grep "Authority\|TeamIdentifier" || true

echo "==> Creating DMG..."
rm -f "$DMG_DIR/$DMG_NAME-$VERSION.dmg"

create-dmg \
    --volname "$APP_NAME" \
    --volicon "$PROJECT_DIR/ClaudeUsage/Resources/AppIcon.icns" \
    --window-pos 200 120 \
    --window-size 600 400 \
    --icon-size 100 \
    --icon "$APP_NAME.app" 175 190 \
    --hide-extension "$APP_NAME.app" \
    --app-drop-link 425 190 \
    --no-internet-enable \
    "$DMG_DIR/$DMG_NAME-$VERSION.dmg" \
    "$BUILD_DIR/$APP_NAME.app" \
    2>&1 || true

# Fallback if create-dmg fails (e.g., no icon file)
if [ ! -f "$DMG_DIR/$DMG_NAME-$VERSION.dmg" ]; then
    echo "==> create-dmg with options failed, using simple DMG..."
    create-dmg \
        --volname "$APP_NAME" \
        --window-pos 200 120 \
        --window-size 600 400 \
        --icon-size 100 \
        --icon "$APP_NAME.app" 175 190 \
        --hide-extension "$APP_NAME.app" \
        --app-drop-link 425 190 \
        --no-internet-enable \
        "$DMG_DIR/$DMG_NAME-$VERSION.dmg" \
        "$BUILD_DIR/$APP_NAME.app" \
        2>&1 || true
fi

# Final fallback — plain hdiutil
if [ ! -f "$DMG_DIR/$DMG_NAME-$VERSION.dmg" ]; then
    echo "==> Fallback: creating plain DMG with hdiutil..."
    STAGING="$BUILD_DIR/dmg-staging"
    mkdir -p "$STAGING"
    cp -R "$BUILD_DIR/$APP_NAME.app" "$STAGING/"
    ln -s /Applications "$STAGING/Applications"
    hdiutil create \
        -volname "$APP_NAME" \
        -srcfolder "$STAGING" \
        -ov -format UDZO \
        "$DMG_DIR/$DMG_NAME-$VERSION.dmg"
    rm -rf "$STAGING"
fi

if [ ! -f "$DMG_DIR/$DMG_NAME-$VERSION.dmg" ]; then
    echo "ERROR: Failed to create DMG"
    exit 1
fi

echo "==> Signing DMG..."
codesign --sign "Developer ID Application" "$DMG_DIR/$DMG_NAME-$VERSION.dmg"

echo "==> Submitting for notarization..."
xcrun notarytool submit "$DMG_DIR/$DMG_NAME-$VERSION.dmg" \
    --keychain-profile "$KEYCHAIN_PROFILE" \
    --wait

echo "==> Stapling notarization ticket..."
xcrun stapler staple "$DMG_DIR/$DMG_NAME-$VERSION.dmg"

echo "==> Verifying staple..."
spctl --assess --type open --context context:primary-signature "$DMG_DIR/$DMG_NAME-$VERSION.dmg"

DMG_SIZE=$(du -h "$DMG_DIR/$DMG_NAME-$VERSION.dmg" | cut -f1)
echo ""
echo "==> Done! Notarized DMG ready for distribution."
echo "    Path: $DMG_DIR/$DMG_NAME-$VERSION.dmg"
echo "    Size: $DMG_SIZE"
