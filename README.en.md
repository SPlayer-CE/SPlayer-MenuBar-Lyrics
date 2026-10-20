<p align="center">
  <img src="Support/AppIcon.png" width="128" height="128" alt="SPlayer Menu Bar Lyrics app icon">
</p>

# SPlayer Menu Bar Lyrics

<p align="center">
  <a href="README.md">简体中文</a> · <a href="README.en.md"><b>English</b></a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Swift-5-F05138?logo=swift&logoColor=white" alt="Swift 5">
  <img src="https://img.shields.io/badge/macOS-13%2B-000000?logo=apple&logoColor=white" alt="macOS 13+">
  <img src="https://img.shields.io/badge/version-1.2.0-2EA44F" alt="Version 1.2.0">
  <img src="https://img.shields.io/badge/UI%20Language-中文%20%7C%20English-4C9AFF" alt="UI language: Chinese / English">
  <img src="https://img.shields.io/badge/license-AGPL--3.0-blue" alt="License: AGPL-3.0">
</p>

Put the lyrics SPlayer-Next is playing right in your macOS menu bar: word-by-word highlighting, scrolling in sync with the song, and playback controls a click away.

This is a standalone app that reads lyrics and playback progress through SPlayer-Next's **external API**. It does **not modify the client's source code and does not depend on its internals**, so SPlayer-Next upgrades usually require no changes here.

## Features

- **Menu bar lyrics**: the current line appears next to the status bar icon, with a karaoke-style sweep that follows playback. Lines wider than the available space scroll with the sung position, so the ending lands exactly at the line's end instead of being cut off with an ellipsis.
- **Real word-by-word highlighting**: works with lyrics that carry genuine per-word timings (QRC / YRC / TTML). Plain LRC lines stay static rather than faking word timing.
- **Inline controls**: 18 px previous / play-pause / next buttons live on the right side of the lyrics item, so you don't need to open the menu.
- **NetEase Cloud Music favorite**: a heart appears for NetEase tracks and toggles the favorite state right from the menu bar (requires the bundled bridge plugin).
- **Adjustable appearance**: 100–600 px display width, 11–16 pt font size, automatic width, lyric alignment, and music icon position are all configurable.
- **Track info and HUD**: click the song title in the menu for artwork, album, and progress; a HUD briefly appears below the menu bar on track changes.
- **Lyric offset**: nudge lyrics by 0.1 s or 0.5 s when they run ahead of or behind the audio.
- **Notch and multi-display aware**: the item narrows to the available menu bar area on the current screen so it is not clipped by the notch or other items.
- **Update check and diagnostics**: check GitHub Releases from Settings and copy troubleshooting details with one click.
- **Chinese and English UI**: menus, settings, and tooltips update immediately when you switch languages.
- **Lightweight**: no Dock icon, no background daemon; quitting stops everything, and the 30 fps redraw stops while paused or disconnected.

## Why not a plugin?

SPlayer-Next plugins run in a sandboxed subprocess with only `network / control / ui / library / api` permissions. The `ui` permission can add items to a track's context menu but **cannot create menu bar items**, so menu bar lyrics are impossible as a plugin. An external app plus the external API is the only way to obtain lyrics and progress without patching the client.

## Requirements

| Item | Requirement |
| --- | --- |
| OS | macOS 13 Ventura or later |
| Player | [SPlayer-Next](https://splayer-next.imsyy.top) with **Settings → External API** enabled |
| Build | Xcode command line tools (`swiftc`, `swift build`) |
| Favorites (optional) | SPlayer-Next **v1.2.0-nightly.990**, signed in to a NetEase Cloud Music account |

> Enabling **WebSocket** in SPlayer-Next is recommended: track changes, lyrics, and playback state arrive instantly. Without it, the app polls roughly every 0.45 seconds and everything still works.
>
> The external API defaults to port `14558`. On first launch the app reads the port from SPlayer-Next's configuration file automatically.

## Quick Start

### 1. Build and run

```bash
./scripts/build.sh
open "build/SPlayer Menu Bar Lyrics.app"
```

You can also run straight from source while developing:

```bash
swift run SPlayerMenuBarLyrics
```

On launch there is no Dock icon; a music icon plus the current lyric appears in the menu bar.

### 2. Build a DMG (optional)

```bash
./scripts/package.sh
# Output: build/SPlayer-Menu-Bar-Lyrics-1.2.0.dmg
```

The DMG contains the app and an `Applications` shortcut, so you can drag to install. The app is ad-hoc signed and not notarized. If Gatekeeper blocks the first launch, allow it under **System Settings → Privacy & Security**, or right-click the app and choose Open.

## Usage

### Menu bar

- Click the lyrics to open the menu: connection status and the current track at the top; click the song title for the track info panel (artwork, album, progress).
- Use the **Lyric offset** submenu to nudge timing by 0.1 s or 0.5 s.
- The item narrows automatically when menu bar space is tight, including around the notch; you can still reduce the display width manually.
- While the menu is open: `⌘,` opens Settings and `⌘Q` quits.

### Settings

Open **Settings…** from the menu bar, or press `⌘,` while the menu is open.

| Setting | Default | Description |
| --- | --- | --- |
| Show menu bar lyrics | On | Master switch |
| Display width | 287 px | 100–600 px; acts as the maximum with automatic width |
| Automatic width | Off | Fit the current lyric |
| Font size | 13 pt | 11–16 pt |
| Lyric alignment | Left | Left / center / right; also switchable from the menu |
| Icon position | Left of lyrics | Left / right of lyrics / hidden |
| Word-by-word highlight | On | Only applies to lyrics with real word timings |
| Always show controls | On | When off, previous / play-pause / next are hidden while idle |
| Track change HUD | On | Show title, artist, and artwork on track changes |
| Lyric offset | 0.0 s | ±3 s in 0.1 s steps |
| Launch at login | Off | Uses the system login item |
| Interface language | Follow system | Follow system / Simplified Chinese / English |
| External API port | 14558 | "Read SPlayer config" syncs it automatically |

### Favorite button

When a NetEase Cloud Music track is playing, a heart appears at the far right of the lyrics item. An outline means not favorited, a filled heart means favorited, and clicking toggles it. Local files and other streaming sources are not supported; the heart hides automatically for them.

To enable it:

1. Upgrade SPlayer-Next to **v1.2.0-nightly.990** (1.1.0 ships plugin Host API level 3, which lacks `splayer.api.call`).
2. In SPlayer-Next, open **Settings → Plugins → Import local**, and select [plugin/favorite-bridge.js](plugin/favorite-bridge.js). The "Reveal plugin in Finder" button in Settings takes you straight to the bundled copy.
3. Grant the plugin `network` and `api` permissions, then enable it.
4. The menu bar app listens on `127.0.0.1:14561` for favorite requests and reports. **Settings → Favorite Button** shows "Bridge plugin connected" once it is working.

The plugin only uses SPlayer-Next's existing NetEase session and the `song_like` / `likelist` APIs. It never modifies the client's source code.

## How It Works

```
SPlayer-Next ──HTTP /api/now-playing (progress polling)──▶ SPlayerClient
             ──HTTP /api/lyrics (lyric timeline)─────────▶      │
             ──WS  /ws (track / lyric / status)──────────▶      │
                                                                 │
                                            PositionAnchor (monotonic-clock interpolation)
                                                                 ▼
                                               current line index → NSStatusItem custom drawing
```

- The external API's WebSocket filters out high-frequency `position` events, so progress is derived from a polled anchor plus local monotonic-clock interpolation.
- The menu bar redraws lyrics at 30 fps: it paints the unplayed color first, then clips out the played portion according to word progress, producing a continuous sweep. Scroll position is driven by the characters already sung and advances in sync with the highlight.
- Playback commands go through the external API's `POST /api/play | pause | next | prev`.
- Favorites use a local bridge: the app exposes a minimal HTTP interface on port `14561`, and the plugin polls requests and reports state back.

## Development

### Mock server

When no player is running, use the bundled mock server:

```bash
python3 scripts/mock_server.py          # defaults to 127.0.0.1:14558
swift run SPlayerMenuBarLyrics
```

The mock server loops through 8 lines of word-timed lyrics and exposes `/api/now-playing`, `/api/lyrics`, `/api/status`, and `/ws` events with the same shape as SPlayer-Next.

### Tests

```bash
swift test
```

Coverage includes current-line selection, position-anchor interpolation / pause / rate / drift correction, drawing bounds for overlong lyrics, icon and automatic-width layout, artwork parsing, version comparison, and completeness of the Chinese and English strings.

### App icon

`Support/AppIcon.icns` is generated by a script (coral rounded square, music note, and a lyric bar with a sweep):

```bash
swift scripts/GenerateIcon.swift Support/AppIcon.icns
```

### Continuous integration

[.github/workflows/build.yml](.github/workflows/build.yml) runs the tests and builds a universal binary (arm64 + x86_64), DMG, and zip on pushes to `main` / `master`, pull requests, `v*` tags, and manual dispatches. Pushing a tag that matches the `Info.plist` version (for example `v1.2.0`) creates a GitHub Release with the artifacts attached. To reproduce the universal build locally, run `UNIVERSAL=1 ./scripts/package.sh`.

## Known Limitations

- On very small screens or with many other status items, macOS may still hide the item; the width narrows automatically and can also be reduced manually.
- Word-by-word highlighting depends on the lyric source providing real word timings. Plain LRC lines do not get generated word timing.
- Local tracks without lyrics show the song title; when the player is not connected, only the icon is shown.
- The external API has no authentication and listens on localhost by default. Do not enable "Allow LAN access" on untrusted networks.
- The app is ad-hoc signed and not notarized. After rebuilding, macOS may ask for permissions again.

## Project Structure

```
MenuBarLyrics/
├── .github/
│   ├── workflows/build.yml                 # GitHub Actions build and release
│   ├── ISSUE_TEMPLATE/                     # Issue templates
│   └── PULL_REQUEST_TEMPLATE.md
├── Package.swift
├── LICENSE                                 # GNU AGPL v3.0
├── CONTRIBUTING.md
├── SECURITY.md
├── Sources/SPlayerMenuBarLyrics/
│   ├── main.swift / AppDelegate.swift      # Entry point, status bar, and menu
│   ├── MenuBarLyricView.swift              # Custom-drawn lyrics and playback controls
│   ├── SPlayerClient.swift                 # Polling + WebSocket + position anchor + controls
│   ├── Models.swift                        # External API data models
│   ├── Timeline.swift                      # Current-line selection and position interpolation
│   ├── LyricHighlight.swift                # Per-character timings and highlight probing
│   ├── Preferences.swift                   # UserDefaults-backed settings
│   ├── Localization.swift                  # Chinese and English string tables
│   ├── SettingsView.swift                  # SwiftUI settings panel
│   ├── TrackInfoPopover.swift              # Track info and artwork panel
│   ├── TrackHUD.swift                      # Track-change HUD
│   ├── UpdateChecker.swift                 # GitHub Releases update check
│   ├── Diagnostics.swift                   # Diagnostic report export
│   ├── DebugLog.swift                      # Logging compiled only in debug builds
│   ├── AppLinks.swift                      # Repository and external links
│   ├── FavoriteBridge.swift                # Local HTTP favorite bridge
│   └── SPlayerConfigReader.swift           # Reads SPlayer-Next's port configuration
├── plugin/favorite-bridge.js               # SPlayer favorite bridge plugin
├── Support/
│   ├── Info.plist
│   ├── AppIcon.icns
│   └── AppIcon.png                         # Icon used in this README
├── scripts/
│   ├── build.sh                            # Builds the .app
│   ├── package.sh                          # Builds the DMG
│   ├── mock_server.py                      # Local mock server
│   └── GenerateIcon.swift                  # Regenerates the icon
└── Tests/SPlayerMenuBarLyricsTests/
```

## Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) first. Report security issues privately as described in [SECURITY.md](SECURITY.md) rather than opening a public issue.

When filing a bug, use **Copy diagnostics** under Settings → About and include the result.

## License

This project is licensed under the [GNU Affero General Public License v3.0](LICENSE).
