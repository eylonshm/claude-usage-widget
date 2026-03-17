# Claude Usage Widget

A native macOS menu bar app that shows your Claude Code usage and quota data — styled to match the Claude Code CLI aesthetic.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/License-MIT-green)

## Features

- **Menu bar** — Weekly quota percentage always visible; click for a full dropdown with quota bars, today's stats, and model breakdown
- **Desktop widgets** — Small (quota ring), Medium (quota bars + stats), Large (full dashboard)
- **Settings window** — Usage overview, model breakdown, lifetime totals, and full customization
- **Auto-updates** — Built-in Sparkle updater keeps the app current
- **No cloud** — Reads local `~/.claude/stats-cache.json` and runs `claude /usage` directly; no API keys or OAuth needed

## Requirements

- macOS 14 (Sonoma) or later
- [Claude Code CLI](https://claude.ai/code) installed and authenticated

## Installation

### Option 1: Homebrew (recommended)

```bash
brew install --cask eylonshm/tap/claude-usage-widget
```

Homebrew handles Gatekeeper automatically — no extra steps needed.

### Option 2: Download DMG

**[Download latest DMG](https://github.com/eylonshm/claude-usage-widget/releases/latest)**

1. Open the DMG and drag **Claude Usage** to your Applications folder
2. On first launch, macOS will block the app (it's unsigned). To open it:
   - **Easiest**: Right-click the app in Finder → **Open** → **Open**
   - **Terminal**: `xattr -cr /Applications/Claude\ Usage.app`

### Option 3: Build from Source

```bash
brew install xcodegen
git clone https://github.com/eylonshm/claude-usage-widget.git
cd claude-usage-widget
xcodegen generate
open ClaudeUsage.xcodeproj
```

Build and run with `Cmd+R`.

## Getting Started

1. The app appears as a **sparkle icon** in the menu bar showing your weekly quota %
2. Click the icon to see the full usage dropdown
3. Add desktop widgets: right-click desktop → Edit Widgets → search "Claude Usage"
4. Click the gear icon in the dropdown to open Settings

## Configuration

| Setting | Options | Default |
|---|---|---|
| Refresh Interval | 5, 10, 15, 30 min | 10 min |
| Warning Threshold | 50–100% | 80% |
| Launch at Login | On/Off | Off |
| Show Menu Bar | On/Off | On |
| Colors | Full palette | Claude Code theme |
| CLI Path | Auto-detected or manual | Auto |

## License

MIT
