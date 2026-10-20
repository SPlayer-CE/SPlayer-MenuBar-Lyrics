# Contributing

Thanks for helping improve SPlayer Menu Bar Lyrics. Issues and pull requests in Chinese or English are both welcome.

## Requirements

- macOS 13 or later with Xcode command line tools
- [SPlayer-Next](https://splayer-next.imsyy.top) with **Settings → External API** enabled

## Build and test

```bash
swift build
swift test
./scripts/build.sh
```

To reproduce a release build with both architectures:

```bash
UNIVERSAL=1 ./scripts/package.sh
```

## Developing without a player

The bundled mock server provides `/api/now-playing`, `/api/lyrics`, `/api/status`, and `/ws`:

```bash
python3 scripts/mock_server.py
swift run SPlayerMenuBarLyrics
```

Debug-only helpers are available when building from source:

```bash
SPlayerMenuBarLyricsDebug=1 swift run SPlayerMenuBarLyrics
swift run SPlayerMenuBarLyrics --show-settings
swift run SPlayerMenuBarLyrics --test-refresh
swift run SPlayerMenuBarLyrics --test-favorite
```

These flags and the verbose logging are compiled out of release builds.

## Localization

Every user-facing string lives in `Sources/SPlayerMenuBarLyrics/Localization.swift`. Add the key to both the Chinese and English tables; `swift test` fails if either is missing.

## Pull requests

- Keep changes focused and explain the user-visible effect.
- Run `swift test` and, for UI changes, attach a screenshot or short screen recording.
- Update both `README.md` and `README.en.md` when behavior or settings change.
- Mention any follow-up work you intentionally left out.

## Reporting bugs

Use the bug report template and include the output of **Settings → About → Copy diagnostics**. Remove the track title/artist first if you consider them private.

For security issues, follow [SECURITY.md](SECURITY.md) instead of opening a public issue.
