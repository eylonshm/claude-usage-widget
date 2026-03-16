# Claude Usage Widget

A native macOS app that shows your Claude Code usage and quota data in desktop widgets, menu bar, and a settings window — all styled to match the Claude Code CLI aesthetic.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/License-MIT-green)

## Features

### Menu Bar
- Compact weekly quota percentage always visible in the menu bar
- Rich dropdown panel with quota progress bars, today's stats, and model breakdown
- Warning color when usage exceeds configurable threshold (default: 80%)

### Desktop Widgets
- **Small**: Circular progress ring showing weekly quota
- **Medium**: Three quota bars + today's message/session count
- **Large**: Full dashboard with quota, stats, model distribution

### Settings Window
- **Usage tab**: Comprehensive view of all quota data, period stats, model breakdown, lifetime totals
- **Settings tab**: Refresh interval, launch at login, menu bar visibility, warning threshold, full color customization

### Design
- Claude Code CLI-inspired dark theme (fully customizable)
- SF Mono typography throughout
- CLI-style section dividers
- Indigo progress bars, coral warning accents

## How It Works

The app reads usage data from two sources:

1. **`~/.claude/stats-cache.json`** -- Local stats cache maintained by Claude Code (daily activity, token counts by model, lifetime stats)
2. **`claude /usage` command** -- Live quota data (session %, weekly % for all models, weekly % Sonnet only, reset times) extracted by spawning a brief CLI session

No API keys, no OAuth, no cloud services. Everything is local.

## Requirements

- **macOS 14 (Sonoma)** or later
- **Claude Code CLI** installed and authenticated ([claude.ai/code](https://claude.ai/code))

## Installation

### Option 1: Download DMG (Recommended)

1. Go to the [Releases](https://github.com/eylonshm/claude-usage-widget/releases) page
2. Download `ClaudeUsage-x.x.x.dmg`
3. Open the DMG and drag **Claude Usage** to your Applications folder

#### Opening the App (Gatekeeper)

Since this app is not notarized by Apple, macOS will block it on first launch. This is normal for open-source apps. Choose one of these methods:

**Method A -- Right-click (easiest):**
1. Open **Finder** and go to **Applications**
2. **Right-click** (or Control-click) on **Claude Usage**
3. Select **Open** from the context menu
4. In the dialog that appears, click **Open**
5. You only need to do this once -- subsequent launches work normally

**Method B -- System Settings:**
1. Try to open the app normally (it will be blocked)
2. Open **System Settings** -> **Privacy & Security**
3. Scroll down to find the message about "Claude Usage" being blocked
4. Click **Open Anyway**
5. Enter your password when prompted

**Method C -- Terminal (removes quarantine):**
```bash
xattr -cr /Applications/Claude\ Usage.app
```
Then open the app normally.

### Option 2: Build from Source

```bash
# Prerequisites: Xcode 15+, xcodegen
brew install xcodegen

# Clone and build
git clone https://github.com/eylonshm/claude-usage-widget.git
cd claude-usage-widget
xcodegen generate
open ClaudeUsage.xcodeproj
```

Build and run from Xcode (Cmd+R).

#### Build DMG Locally

```bash
brew install create-dmg
./scripts/build-dmg.sh 1.0.0
# Output: dist/ClaudeUsage-1.0.0.dmg
```

## Getting Started

1. **Install the app** using one of the methods above
2. The app appears as a **sparkle icon** in your menu bar with your weekly quota percentage
3. **Click the menu bar icon** to see the full usage dropdown
4. **Add desktop widgets**: Right-click desktop -> Edit Widgets -> Search "Claude Usage"
5. **Open Settings**: Click the gear icon in the dropdown to customize

## Configuration

Open the Settings window from the menu bar dropdown (gear icon):

| Setting | Options | Default |
|---------|---------|---------|
| Refresh Interval | 5, 10, 15, 30 minutes | 10 min |
| Warning Threshold | 50-100% | 80% |
| Launch at Login | On/Off | Off |
| Show Menu Bar | On/Off | On |
| Colors | Full palette customization | Claude Code theme |
| CLI Path | Auto-detected or manual | Auto |

## Project Structure

```
ClaudeUsage/
  Sources/
    App/           -- Main app entry point (MenuBarExtra + Settings window)
    Models/        -- Data models (StatsCache, QuotaData, WidgetData)
    Services/      -- Data fetching (StatsFetcher, QuotaFetcher, UsageDataService)
    Views/
      Components/  -- Reusable UI (ProgressBar, StatRow, SectionDivider, ModelBar)
      MenuBar/     -- Menu bar dropdown panel
      Settings/    -- Settings window (Usage + Settings tabs)
    Theme/         -- Design system (colors, typography, settings)
ClaudeUsageWidget/
  Sources/         -- WidgetKit extension (Small, Medium, Large widgets)
scripts/
  build-dmg.sh     -- Build script for creating DMG installer
```

## Tech Stack

- **SwiftUI** -- All UI
- **WidgetKit** -- Desktop widgets
- **MenuBarExtra** -- Menu bar integration
- **PTY/Process** -- CLI interaction for quota data
- **App Groups** -- Data sharing between app and widget extension
- **XcodeGen** -- Project generation from `project.yml`

## Contributing

1. Fork the repo
2. Create your feature branch (`git checkout -b feat/amazing-feature`)
3. Commit your changes (`git commit -m 'feat: add amazing feature'`)
4. Push to the branch (`git push origin feat/amazing-feature`)
5. Open a Pull Request

## License

MIT
