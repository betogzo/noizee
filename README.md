# Noizee

Private macOS app — native Swift/SwiftUI front end for YouTube Music (API via `YTMusicClient`, DRM playback in a hidden WebView). This README is for you and anyone with repo access: clone, build, run, and where to read more.

This app is a direct fork from https://github.com/sozercan/kaset with enhanced features.

## Requirements

- **macOS 26** (matches `Package.swift`)
- **Xcode** with a Swift **6.2** toolchain (open `Package.swift` once so Xcode resolves the SwiftPM graph)
- **SwiftLint** and **SwiftFormat** (for the lint/format loop in `AGENTS.md`)

## Clone

Use whatever remote you use for this repo (SSH or HTTPS). Example:

```bash
git clone <your-remote-url> Noizee
cd Noizee
```

First clone will fetch the **Sparkle** dependency over the network when you build.

## Build

```bash
swift build
```

Release binary (after a successful build): `.build/release/Noizee` — *not* a full `.app` bundle; use the scripts below for a runnable app.

## Run (packaged app)

The usual dev loop builds a proper bundle and launches it:

```bash
Scripts/compile_and_run.sh
```

Handy variants:

- `Scripts/compile_and_run.sh --test` — run SwiftPM unit tests before packaging
- `Scripts/compile_and_run.sh --lint` — run SwiftLint + SwiftFormat before packaging
- `Scripts/compile_and_run.sh --wait` — if another compile-and-run is holding the lock, wait instead of exiting

Package only (output: `.build/app/Noizee.app`):

```bash
Scripts/build-app.sh
```

Open the bundle manually if you want:

```bash
open .build/app/Noizee.app
```

## Distribution (DMG installer)

To ship a drag-to-**Applications** disk image with a large app icon and an **Applications** shortcut, use [create-dmg](https://github.com/create-dmg/create-dmg) (not a SwiftPM dependency — install via Homebrew):

```bash
brew install create-dmg
```

1. **Build** a signed `.app` (example: universal **Apple Silicon + Intel**, ad-hoc signing for local distribution):

   ```bash
   ARCHES="arm64 x86_64" NOIZEE_SIGNING=adhoc ./Scripts/build-app.sh release
   ```

   For a single-architecture build, omit `ARCHES` (the script defaults to the host CPU).

2. **Create the DMG** (reads `version.env` for the output filename; writes under `dist/`, which is gitignored):

   ```bash
   ./Scripts/create-installer-dmg.sh
   ```

   - Custom output path: `OUTPUT_PATH=~/Desktop/Noizee.dmg ./Scripts/create-installer-dmg.sh`
   - Optional window background: `NOIZEE_DMG_BACKGROUND=/path/to/660x420.png ./Scripts/create-installer-dmg.sh`

If `swift build` fails with a confusing `…release.exe` message on macOS, clear SwiftPM state and rebuild (e.g. `rm -rf .build` then run `build-app.sh` again). See `Scripts/build-app.sh` and `Scripts/create-installer-dmg.sh` for details.

## Tests

Default unit-test pass (CLI; does **not** launch the separate UI-test project):

```bash
swift test --skip NoizeeUITests
```

Filtered run:

```bash
swift test --skip NoizeeUITests --filter SomeTestName
```

**UI tests** live under `NoizeeUITests.xcodeproj` and launch the app — disruptive on a dev machine, so only run when you mean it (e.g. open the project in Xcode and run the `NoizeeUITests` scheme).

## API Explorer

Before changing YouTube Music API usage, explore endpoints with the bundled CLI:

```bash
swift run api-explorer auth
swift run api-explorer list
swift run api-explorer browse FEmusic_home -v
```

More detail: `.agents/skills/api-exploration/SKILL.md` and `Sources/APIExplorer/main.swift`.

## Lint and format

```bash
swiftlint --strict && swiftformat .
```

## Xcode

Open **`Package.swift`** in Xcode for SPM-based editing, breakpoints, and Instruments.

For UI tests, open **`NoizeeUITests.xcodeproj`**.

## Docs and conventions

| Doc | Purpose |
|-----|--------|
| [`AGENTS.md`](AGENTS.md) | AI + human dev rules (logging, concurrency, shortcuts, API discovery) |
| [`CONTRIBUTING.md`](CONTRIBUTING.md) | Structure, architecture pointers, contribution workflow |
| [`docs/`](docs/) | Architecture, playback, testing, ADRs |

## Other

- **Last.fm proxy worker** (Cloudflare): see [`worker/README.md`](worker/README.md).
- **Cache / state issues**: `Scripts/purge-noizee-caches.sh` (use when debugging stale WebKit or app support data).
