# Notch Control Center

### Turn your MacBook notch into a live control center

Native **macOS** app · **Swift + SwiftUI** · Menu bar utility · **MIT licensed**

[![Download](https://img.shields.io/badge/Download-v1.0.1-blue?style=for-the-badge)](https://github.com/tigeromp/notch-control-center/releases/latest)
[![macOS 13+](https://img.shields.io/badge/macOS-13%2B-000000?style=flat-square&logo=apple)](https://github.com/tigeromp/notch-control-center)
[![Swift](https://img.shields.io/badge/Swift-5.9-F05138?style=flat-square&logo=swift&logoColor=white)](https://github.com/tigeromp/notch-control-center)
[![License MIT](https://img.shields.io/badge/License-MIT-green?style=flat-square)](LICENSE)

![Demo](https://github.com/tigeromp/notch-control-center/raw/main/docs/screenshots/notch-demo.gif)

**Music · Live stocks · Live sports · Weather · News · Calendar · Timer · Crypto**

---

## Quick start

**Download:** [Releases](https://github.com/tigeromp/notch-control-center/releases/latest) → unzip → move to Applications.

**Build from source:**

```bash
git clone https://github.com/tigeromp/notch-control-center.git
cd notch-control-center
bash scripts/run.sh
```

Look for the **music-note icon** in your menu bar.

## Features

- **Music** — Apple Music + Spotify controls with artwork
- **Stocks & crypto** — live tickers with flash on price changes
- **Sports** — live games only (NFL, NBA, MLB, NHL, soccer, cricket, NCAA)
- **News, weather, calendar, timer, meeting mode**
- **Three-finger swipe down** to open · move away / **Esc** / click notch to close
- **Appearance** settings — text size, colors, accent, panel style

## Permissions

| Permission | Why |
|------------|-----|
| **Accessibility** | Three-finger swipe to open |
| **Automation** | Spotify control |
| **Calendar** | Events widget |

## Requirements

- macOS **13 Ventura** or later (including **14 Sonoma**, **15 Sequoia**, and newer)
- MacBook with notch recommended (works on other Macs — panel sits top-center)

## Build release

```bash
bash scripts/build-app.sh
bash scripts/release.sh 1.0.0
```

## License

MIT — see [LICENSE](LICENSE).
