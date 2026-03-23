# Claude Meter

A native macOS menu bar app that tracks your [Claude Code](https://claude.ai/code) session quota, weekly usage, and token breakdown — all without any API keys or account setup. Just install and go.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/License-MIT-green)

## Screenshots

<p align="center">
  <img src="docs/claudeUsageExample1.png" width="580" alt="Settings window" />
</p>
<p align="center">
  <img src="docs/ClaudeMeterExampleTwo.png" height="380" alt="Menu bar dropdown" />
  &nbsp;&nbsp;
  <img src="docs/ClaudeWidgetExampleThree.png" height="380" alt="Desktop widgets" />
</p>

## Features

- **Menu bar icon** — Shows your weekly quota % at a glance; click for a full dropdown with session quota, weekly usage, and model breakdown
- **Session countdown** — Alerts you when your current session is about to reset
- **Desktop widgets** — Small (quota ring), Medium (quota bars + model stats), Large (full dashboard) — add them via right-click → Edit Widgets
- **Model breakdown** — See token usage split across Opus, Sonnet, and Haiku
- **Lifetime stats** — Total messages, sessions, and member-since date
- **Auto-updates** — Built-in updater keeps the app current silently in the background
- **Fully local** — Reads `~/.claude/stats-cache.json` and calls the Claude Code CLI directly; no API keys, no OAuth, no accounts

## Requirements

- macOS 14 (Sonoma) or later
- [Claude Code CLI](https://claude.ai/code) installed and authenticated

## Installation

### Option 1: Homebrew (recommended)

```bash
brew install --cask eylonshm/tap/claude-meter
```

Homebrew handles Gatekeeper automatically — no extra steps needed.

### Option 2: Download DMG

**[Download latest DMG](https://github.com/eylonshm/claude-meter/releases/latest)**

1. Open the DMG and drag **Claude Meter** to your Applications folder
2. Launch it from Applications or Spotlight — macOS may ask you to confirm opening it the first time

### Option 3: Build from Source

```bash
brew install xcodegen
git clone https://github.com/eylonshm/claude-meter.git
cd claude-meter
xcodegen generate
open ClaudeMeter.xcodeproj
```

Build and run with `Cmd+R`.

## Getting Started

1. **Launch Claude Meter** from Applications or Spotlight — it runs as a menu bar app with no dock icon
2. Look for a **small circle icon** (⊙) in your menu bar — this is Claude Meter. Click it to see your usage dropdown
3. If you don't see it right away, make sure the app is running (check via Spotlight or Activity Monitor)
4. To add **desktop widgets**: right-click the desktop → Edit Widgets → search "Claude Meter"
5. Click the **gear icon** in the dropdown to open Settings and configure refresh interval, colors, and more

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
