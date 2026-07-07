# Notch Control Center v1.0.0

First public release — a native macOS notch control panel built with Swift and SwiftUI.

## Highlights

- **Notch panel** — expands from the top of your screen with music, widgets, and controls
- **Music** — Apple Music and Spotify (now playing, artwork, play/pause, skip, scrub)
- **Live widgets** — stocks, crypto, live sports scores, news, weather, calendar, timer, meeting mode
- **Flash updates** — stocks flash green/red on price changes; live games flash your accent color
- **Gestures** — three-finger swipe down to open; move cursor away to close
- **Appearance** — text size, colors, accent, panel style

## Install

1. Download `NotchControlCenter-1.0.0.zip` below
2. Unzip and move **Notch Control Center.app** to Applications
3. Open the app (right-click → Open if macOS blocks an unsigned build)
4. Look for the **music-note menu bar icon**

## Permissions

- **Accessibility** — required for three-finger swipe to open (System Settings → Privacy & Security → Accessibility)
- **Automation** — for Spotify control
- **Calendar** — for events widget (optional)

## Requirements

- macOS 14 Sonoma or later
- MacBook with notch recommended (works on other Macs — panel sits top-center)

## Known limitations

- Stock/sports data uses public APIs; updates depend on market hours and live games
- Flash animations show when the panel is **expanded** (data still updates in the background when collapsed)
- First launch may require allowing the app in Privacy settings

## Build from source

```bash
git clone https://github.com/ompopat09/notch-control-center.git
cd notch-control-center
bash scripts/run.sh
```
