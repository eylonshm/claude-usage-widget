## Why

Users currently have no in-app way to discover or install updates — they must manually check GitHub or re-run Homebrew. Adding Sparkle gives the app a "Check for Updates" button and enables automatic background update checks, closing the gap between shipping new releases and users receiving them.

## What Changes

- Add Sparkle 2 as an SPM dependency in `project.yml`
- Generate an EdDSA key pair; embed the public key in `Info.plist` (`SUPublicEDKey`) and store the private key as a GitHub Actions secret
- Add `SUFeedURL` to `Info.plist` pointing to `https://raw.githubusercontent.com/eylonshm/claude-usage-widget/main/appcast.xml`
- Wire up `SPUStandardUpdaterController` in `AppDelegate` (init on launch, check on first launch)
- Add "Check for Updates" button to the Settings tab in `SettingsWindow.swift`
- Extend the GitHub Actions release workflow to sign the DMG with `generate_appcast`, then commit the updated `appcast.xml` back to `main`

## Capabilities

### New Capabilities
- `auto-update`: Sparkle-powered in-app update checking and installation, including appcast generation in CI and a "Check for Updates" UI entry point

### Modified Capabilities
- `settings-ui`: Add "Check for Updates" button to the Settings tab (new UI element, no requirement-level behavior change to existing settings)

## Impact

- **`project.yml`**: new `packages` section for Sparkle SPM; new dependency on `ClaudeUsage` target
- **`ClaudeUsage/Resources/Info.plist`**: two new keys (`SUFeedURL`, `SUPublicEDKey`)
- **`ClaudeUsage/Sources/App/ClaudeUsageApp.swift`**: `AppDelegate` gains `SPUStandardUpdaterController` property
- **`ClaudeUsage/Sources/Views/Settings/SettingsWindow.swift`**: new "Check for Updates" row in `SettingsTab`
- **`.github/workflows/release.yml`**: install Sparkle tools, run `generate_appcast`, commit `appcast.xml`
- **`appcast.xml`** (new file at repo root): Sparkle feed, committed and updated on each release
- **GitHub Actions secrets**: `SPARKLE_PRIVATE_KEY` must be added by the maintainer
