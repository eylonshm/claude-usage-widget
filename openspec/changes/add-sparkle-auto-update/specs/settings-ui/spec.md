## ADDED Requirements

### Requirement: Check for Updates button in Settings
The Settings tab SHALL include a "Check for Updates" button in a dedicated "Updates" section that triggers `SPUStandardUpdaterController.checkForUpdates(_:)`.

#### Scenario: User taps Check for Updates
- **WHEN** the user opens the Settings window, navigates to the Settings tab, and clicks "Check for Updates"
- **THEN** Sparkle initiates an update check and either shows the update prompt or a "You're up to date" alert

#### Scenario: Button is always enabled
- **WHEN** the Settings tab is displayed
- **THEN** the "Check for Updates" button is enabled regardless of network state or last-check recency (Sparkle handles failure states internally)
