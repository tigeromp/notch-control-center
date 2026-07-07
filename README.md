# Notch Control Center

A native **macOS** utility that turns your MacBook notch into an expandable control panel — music, live stocks, sports scores, weather, news, calendar, timers, and more.

Built with **Swift + SwiftUI**. Runs as a menu bar app (no Dock icon).

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange)
![License MIT](https://img.shields.io/badge/license-MIT-green)

## Features

### Panel & controls
- Floating panel anchored to the notch / top-center of the screen
- **Three-finger swipe down** to open when collapsed
- Move cursor away, press **Esc**, click the notch, or tap **↑** to close
- Menu bar icon for toggle and settings
- Customizable **appearance** (text size, colors, accent, panel opacity)

### Widgets (toggle any in ⚙ settings)
| Widget | Description |
|--------|-------------|
| **Music** | Apple Music + Spotify — artwork, play/pause, skip, progress |
| **Stocks** | Live watchlist ticker with green/red flash on price changes |
| **Crypto** | BTC, ETH, and more |
| **Sports** | **Live games only** — NFL, NBA, MLB, NHL, soccer, cricket, NCAA |
| **News** | Headlines matched to your weather region (US by default) |
| **Weather** | Current conditions |
| **Calendar** | Today's events |
| **Timer** | Stopwatch and custom timers |
| **Meeting mode** | Next meeting + quick join |

### Live updates
- Stocks and sports refresh every **2 seconds** while running
- Price/score changes show a brief **colored flash** behind the item (green/red for stocks, accent color for games)
- Flashes are visible when the panel is **expanded**; data still updates in the background when collapsed

## Requirements

- macOS **14 Sonoma** or later
- MacBook with notch recommended (works on other Macs)
- Xcode Command Line Tools: `xcode-select --install`

## Install (pre-built)

1. Go to **[Releases](https://github.com/ompopat09/notch-control-center/releases)** and download the latest `.zip`
2. Unzip → move **Notch Control Center.app** to Applications
3. Open the app (right-click → **Open** if Gatekeeper warns on first launch)
4. Look for the **music-note** icon in the menu bar

## Build & run from source

```bash
git clone https://github.com/ompopat09/notch-control-center.git
cd notch-control-center
bash scripts/run.sh
```

Or build only:

```bash
bash scripts/build-app.sh
open "dist/Notch Control Center.app"
```

## First-launch permissions

| Permission | Why |
|------------|-----|
| **Accessibility** | Three-finger swipe to open the panel |
| **Automation** (Spotify) | Control Spotify playback |
| **Calendar** | Show upcoming events |
| **Media** | Read now-playing info from Apple Music |

Enable in **System Settings → Privacy & Security**.

## Usage

| Action | How |
|--------|-----|
| Open panel | Three-finger swipe **down** on trackpad (when collapsed) |
| Close panel | Move mouse away, **Esc**, click notch, or **↑** button |
| Widget settings | Click **⚙** in the panel |
| Appearance | ⚙ → **Appearance & Format** |
| Quit | Menu bar icon → Quit |

## Release build (developers)

```bash
# Build zip (auto-signs if Developer ID cert is in Keychain)
bash scripts/release.sh 1.0.0

# Optional notarized release (Apple Developer account)
NOTARIZE=1 APPLE_ID=you@email.com APPLE_TEAM_ID=XXXXXXXXXX \
  APPLE_APP_PASSWORD=xxxx-xxxx-xxxx-xxxx \
  bash scripts/release.sh 1.0.0

# Push to GitHub + create release (requires: gh auth login)
bash scripts/publish-github.sh 1.0.0
```

## Project structure

```
notch-control-center/
├── Sources/NotchControlCenter/   # Swift source
├── Resources/Info.plist
├── scripts/
│   ├── build-app.sh              # Build .app bundle
│   ├── run.sh                    # Build + launch
│   ├── release.sh                # Sign, zip, optional notarize
│   └── publish-github.sh         # Push + GitHub Release
├── Package.swift
└── RELEASE_NOTES.md
```

## Customize

- Panel sizes → `NotchGeometry.swift`
- UI & widgets → `NotchView.swift`, `NotchWidgetModules.swift`
- Colors & fonts → `NotchAppearanceStore.swift`, `AppearanceSettingsView.swift`
- Gestures → `ThreeFingerGestureMonitor.swift`

## Data sources

Stocks, sports, news, weather, and crypto use public third-party APIs. Availability depends on market hours, live games, and network conditions. Not financial advice.

## License

MIT — see [LICENSE](LICENSE).

## Author

**Om Popat** — [GitHub](https://github.com/ompopat09)
