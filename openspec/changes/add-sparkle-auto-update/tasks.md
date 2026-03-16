## 1. One-time Key Generation (manual, done once by maintainer)

- [x] 1.1 Download the Sparkle 2 release archive and extract `bin/generate_keys`
- [x] 1.2 Run `./generate_keys` to produce an EdDSA key pair; copy the private key into GitHub repo secret `SPARKLE_PRIVATE_KEY`
- [x] 1.3 Note the public key string output by `generate_keys` for use in step 2.3

## 2. Project Configuration

- [x] 2.1 Add a `packages` section to `project.yml` declaring the Sparkle SPM package at `https://github.com/sparkle-project/Sparkle` pinned to version `2.7.0`
- [x] 2.2 Add `Sparkle` as a linked framework dependency on the `ClaudeUsage` target in `project.yml`
- [x] 2.3 Add `SUPublicEDKey` (the base64 public key from step 1.3) to the `ClaudeUsage` target's `info.properties` in `project.yml`
- [x] 2.4 Add `SUFeedURL` set to `https://raw.githubusercontent.com/eylonshm/claude-usage-widget/main/appcast.xml` to the `ClaudeUsage` target's `info.properties` in `project.yml`
- [x] 2.5 Add `SUEnableAutomaticChecks` set to `true` to the `ClaudeUsage` target's `info.properties` in `project.yml`
- [x] 2.6 Regenerate the Xcode project with `xcodegen generate` and verify it resolves the Sparkle package

## 3. AppDelegate Wiring

- [x] 3.1 Import `Sparkle` at the top of `ClaudeUsageApp.swift`
- [x] 3.2 Add a `var updaterController: SPUStandardUpdaterController!` stored property to `AppDelegate`
- [x] 3.3 In `applicationDidFinishLaunching`, initialize `updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)` before any other setup
- [x] 3.4 Expose the updater via a static accessor (e.g., `AppDelegate.shared.updaterController.updater`) so the Settings view can call `checkForUpdates`

## 4. Settings UI

- [x] 4.1 In `SettingsWindow.swift` inside `SettingsTab.body`, add a new `VStack` section with `SectionHeader(title: "Updates")` before the closing of the scroll content
- [x] 4.2 Inside the Updates section, add a Button labeled "Check for Updates" that calls `AppDelegate.shared.updaterController.updater.checkForUpdates(nil)` (or equivalent)
- [x] 4.3 Style the button consistently with the existing "Reset to Defaults" button (plain style, glass card container, accent color)
- [x] 4.4 Wrap the updates section in `.glassCard(cornerRadius: 12)` to match other settings sections

## 5. Release Workflow

- [x] 5.1 In `.github/workflows/release.yml`, add a step after "Create DMG" to download the Sparkle release archive and extract `bin/generate_appcast` and `bin/sign_update`
- [x] 5.2 Add a step to run `generate_appcast` on the built DMG, passing the private key via `${{ secrets.SPARKLE_PRIVATE_KEY }}`, and writing the output to `appcast.xml` at the repo root
- [x] 5.3 Add a step to configure git user (`github-actions[bot]`) and commit `appcast.xml` with message `chore: update appcast for v${{ steps.version.outputs.VERSION }}`
- [x] 5.4 Add a step to push the commit back to `main` using the default `GITHUB_TOKEN`
- [ ] 5.5 Verify the workflow by doing a dry-run on a test tag; confirm `appcast.xml` is committed and the DMG URL, version, length, and EdDSA signature fields are all populated correctly

## 6. Initial Appcast Bootstrap

- [x] 6.1 Create a minimal `appcast.xml` at the repo root with the correct Sparkle XML structure (channel, title, `sparkle:minimumSystemVersion`) but no items yet, so the file exists before the first automated release
- [x] 6.2 Commit `appcast.xml` to `main` (it will be overwritten by CI on the next release tag)
