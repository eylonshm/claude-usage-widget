## Context

Claude Usage Widget is a macOS 14+ menu bar app distributed as an unsigned DMG via GitHub Releases and as a Homebrew cask. It has no update mechanism today. Sparkle 2 is the de-facto standard for macOS app auto-updates outside the App Store. The app uses XcodeGen (`project.yml`) for project generation, Swift Package Manager for potential future dependencies, and GitHub Actions for CI/CD.

The app is **unsigned and unnotarized**. Apple code signing is irrelevant here; Sparkle's own EdDSA signature on the update package is what matters — it prevents a MITM from serving a malicious update to users who have trusted the app.

## Goals / Non-Goals

**Goals:**
- Users see a "Check for Updates" button in Settings that triggers an immediate update check
- The app checks for updates automatically in the background on launch
- Updates are signed with EdDSA so Sparkle can verify authenticity before installing
- The release CI generates and commits an up-to-date `appcast.xml` automatically on each tag push
- The `appcast.xml` is hosted at a stable raw GitHub URL (no separate hosting required)

**Non-Goals:**
- Delta/binary-diff updates (full DMG replacement is fine at this app's size)
- Staged rollouts or canary releases
- Silent background install without user confirmation (Sparkle shows a prompt)
- Homebrew users are not served by Sparkle (they use `brew upgrade`)

## Decisions

### Decision: EdDSA key storage
**Choice**: Store the private key as a GitHub Actions secret (`SPARKLE_PRIVATE_KEY`); embed the public key as `SUPublicEDKey` in `Info.plist` via `project.yml`.

**Rationale**: The private key must never be committed to the repo. Sparkle's `generate_keys` tool outputs a base64 key pair; the public half is safe to embed. The private half signs each release artifact in CI.

**Alternative considered**: Hardcoded key in CI environment variable set at org level. Rejected — secret scoping to the repo is safer.

---

### Decision: Appcast hosting via raw GitHub URL on `main`
**Choice**: Commit `appcast.xml` to the repo root and serve it at `https://raw.githubusercontent.com/eylonshm/claude-usage-widget/main/appcast.xml`.

**Rationale**: No separate hosting infrastructure needed. The release workflow already has `contents: write` permission. Raw GitHub URLs are stable and free. The CI job commits the updated appcast back to `main` after each release.

**Alternative considered**: GitHub Pages / separate CDN. Rejected — unnecessary complexity for a single-file feed.

---

### Decision: Sparkle version pinned via SPM exact version
**Choice**: Pin Sparkle to a specific release tag (e.g., `2.7.0`) in `project.yml`'s `packages` section.

**Rationale**: Avoids unexpected breakage from upstream Sparkle changes. Can be bumped deliberately.

---

### Decision: `SPUStandardUpdaterController` initialized in `AppDelegate`
**Choice**: Add `SPUStandardUpdaterController` as a stored property on `AppDelegate`, initialized in `applicationDidFinishLaunching`.

**Rationale**: `AppDelegate` already owns first-launch logic. Sparkle's standard controller handles the full update UI lifecycle; we just need to hold a strong reference and expose `checkForUpdates(_:)` to the Settings view via a shared accessor.

**Alternative considered**: Initialize in `ClaudeUsageApp` body. Rejected — `@main App` structs have limited lifecycle hooks; `AppDelegate` is already in use and is the right owner.

---

### Decision: "Check for Updates" placed in Settings tab, not menu bar dropdown
**Choice**: Add the button to the `SettingsTab` in `SettingsWindow.swift` under a new "Updates" section.

**Rationale**: The menu bar dropdown is intentionally minimal (quota info + refresh + settings icon). Settings is the natural home for app management actions. Keeps the dropdown uncluttered.

---

### Decision: `generate_appcast` run in CI, appcast committed to `main`
**Choice**: After the DMG is built and uploaded to the GitHub Release, download Sparkle's tooling, run `generate_appcast` on the DMG, then `git commit` + `git push` the updated `appcast.xml` to `main`.

**Rationale**: Fully automated — no manual appcast editing after each release. The CI job already has push access via `GITHUB_TOKEN`. The commit is a simple "chore: update appcast for vX.Y.Z" on `main`.

**Alternative considered**: Commit appcast as a separate GitHub Release artifact and point the feed URL there. Rejected — the URL would change per release, breaking the static feed URL embedded in the app.

## Risks / Trade-offs

- **[Risk] CI pushes directly to `main`** → Mitigation: The commit is scoped to `appcast.xml` only and gated behind a successful build + release. Branch protection rules (if any) may need a bypass or the workflow can use a dedicated bot token.
- **[Risk] Sparkle prompt appears over the menu bar window** → Mitigation: `SPUStandardUpdaterController` manages window ordering; Sparkle 2 handles this correctly for menu-bar-only apps (no Dock icon, `LSUIElement: true`).
- **[Risk] Users on Homebrew receive duplicate update prompts** → Mitigation: No mitigation needed — Sparkle and Homebrew operate independently. Homebrew users can simply dismiss the in-app prompt.
- **[Risk] Private key rotation** → Mitigation: Rotate the GitHub secret and update `SUPublicEDKey` in `Info.plist` in the same release. Old versions will no longer trust new updates until the user reinstalls — this is a known Sparkle limitation.

## Migration Plan

1. Maintainer runs `generate_keys` locally once, saves the private key to `SPARKLE_PRIVATE_KEY` GitHub secret, adds public key to `Info.plist` via `project.yml`.
2. Merge this branch; the next tag push triggers CI which builds, releases, and publishes `appcast.xml`.
3. Existing users on older versions without Sparkle receive no auto-update (expected); new installs will get Sparkle from this release forward.

## Open Questions

- Should auto-check on launch be enabled by default, or opt-in via a Settings toggle? **Proposed**: enabled by default (`SUEnableAutomaticChecks: true` in Info.plist) — consistent with standard macOS app behavior.
- Does the repo have branch protection on `main` that would block the CI commit? Needs verification before merging.
