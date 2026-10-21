# Developing Transflo

## Requirements
- macOS 14+ on Apple silicon
- Xcode 26 or newer, plus `brew install xcodegen swiftlint`

## Build
```bash
brew install pkg-config meson ninja cmake nasm autoconf automake libtool
```

```bash
./scripts/build-ffmpeg.sh
```

```bash
./scripts/bootstrap.sh
```

```bash
open Transflo.xcodeproj
```

- **`build-ffmpeg.sh`** builds the LGPL-only ffmpeg into `Vendor/ffmpeg/bin`. It verifies pinned checksums and takes about 15 minutes, once.
- **`bootstrap.sh`** generates `Transflo.xcodeproj` from `project.yml`. The project file isn't committed.
  The post-generation step converts physical directories to Xcode synchronized folders, preserving target
  exclusions and shared UI-test sources. Added or removed files appear automatically in the navigator.
  Python 3 and macOS `plutil` are required; no additional Python packages are needed.

## iPhone and iPad

The `TransfloMobile` scheme targets iOS and iPadOS 17 or later. Generate the project with
`scripts/bootstrap.sh`, select that scheme, then choose an iPhone or iPad simulator in Xcode.
The mobile target does not need the ffmpeg helper build. It shares TransfloDomain, TransfloData,
the design system, localization, wheel coordination and job management with the Mac app.

The mobile app imports from Files, Photos and drag and drop, opens an in-app
searchable Convert/Tools/Actions picker, runs supported native conversions and tools, and shares completed
results through the system share sheet. Imports and outputs live in the app's Documents folder,
visible in Files. Home, Files, Activity and Settings use native system tabs, with Liquid Glass on supported
OS versions. Settings include native menus for language and appearance, accent, reduced motion,
and a separate About screen. A first-run-only tour introduces the action lists and sharing.
Home offers readable categories derived from runnable source formats. Successful jobs automatically
open saving: compatible images offer Photos or Files, and other results open the system share sheet.
Photos uses add-only access, requested only when the user chooses Save to Photos.
Mobile image/PDF/metadata/rename and markup editors reuse shared engines. Media editors use native
AVFoundation processing, with source playback, trim-range and speed previews, scrubbing and frame selection.
The Share extension presents the same action picker and editors. See `MOBILE_PARITY.md` for remaining gaps.

Run the mobile suite on each device family:

```bash
xcodebuild test -project Transflo.xcodeproj -scheme TransfloMobile \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro Max' \
  -destination 'platform=iOS Simulator,name=iPad Air 11-inch (M4)' \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO
```

Use device names installed with your Xcode. Mobile tests include a real image import, PNG conversion
and result-sharing integration test; the UI smoke test checks launch and rotation.

## Test
```bash
swiftlint lint --strict
```

```bash
for p in Packages/*/; do
  swift test --package-path "$p" --scratch-path "${TMPDIR:-/tmp}/transflo-tests-$(basename "$p")" || exit 1
done
```

```bash
xcodebuild test -project Transflo.xcodeproj -scheme TransfloForMac -testPlan Fast -destination 'platform=macOS' \
  -derivedDataPath "${TMPDIR:-/tmp}/transflo-tests-xcode"
```

Xcode's **Product → Test Plan** menu selects the same checked-in plans:

| Plan | Coverage | When to run |
| --- | --- | --- |
| Fast (default) | All app unit tests and 24 UI regressions: persistence, sizing, language switching, keyboard, onboarding, wheels, jobs, shelf and updates | Cmd-U and every pull request |
| Extended | 25 additional UI tests: every remaining editor, editor fit in both languages, locale/theme variants, all-tab sizing, multi-file wheels, update results and automatic result dismissal | Before merging; CI on `main` and manual runs |

Fast and Extended are disjoint; run both for all functional UI coverage. Package
tests remain separate. To run only the remaining UI tests:

```bash
xcodebuild test -project Transflo.xcodeproj -scheme TransfloForMac -testPlan Extended \
  -destination 'platform=macOS' -parallel-testing-enabled NO \
  -derivedDataPath "${TMPDIR:-/tmp}/transflo-tests-xcode"
python3 scripts/validate-ui-test-plans.py
```

The validator rejects missing, duplicated or stale UI selections when tests change.
Success screenshots are off by default; XCTest's automatic failure diagnostics stay
enabled. Set `TEST_RUNNER_TRANSFLO_UI_SCREENSHOTS=1` for optional diagnostic images.
Keep the Mac unlocked and idle, and use one UI worker (`-parallel-testing-enabled NO`).

Build and signing check:
```bash
xcodebuild build -project Transflo.xcodeproj -scheme TransfloForMac -configuration Release \
  -destination 'generic/platform=macOS' -derivedDataPath "${TMPDIR:-/tmp}/transflo-tests-xcode"
codesign --verify --deep --strict "${TMPDIR:-/tmp}/transflo-tests-xcode/Build/Products/Release/Transflo.app"
```

UI tests use an isolated preference suite, including across relaunches, so color,
appearance, key, and output checks do not change your installed app’s settings.
Debug UI tests temporarily give Transflo a Dock presence so macOS activation reliably
brings its windows forward. Release builds keep the normal menu-bar behavior.
The optional iWork integration matrix needs Pages, Keynote and Numbers installed
and Automation consent. Run it with `TRANSFLO_IWORK_TESTS=1 swift test --package-path
Packages/TransfloData --scratch-path "${TMPDIR:-/tmp}/transflo-tests-TransfloData"`.
The ordinary conversion matrix generates its own synthetic inputs and, with the bundled FFmpeg helpers, checks
every supported path except iWork Automation and legacy PPT/XLS input. The opt-in
[release verification suite](testing/release-verification.md) covers those too, with private fixtures.

`-TransfloOpenWelcome` always replays Getting Started from page 1, even after completion.
In Debug, `-TransfloOnboardingPage <1–5>` opens a particular page for inspection.
The ordinary launch shows the tour only until Done is selected.

UI tests drive the app through debug-only launch arguments (`-TransfloPreviewWheel`, `-TransfloPreviewEditor`, `-TransfloPreviewJobs`, `-TransfloPreviewUpdate` and others; see `TransfloForMac/App/LaunchArgument.swift`), because real Finder drags can't be automated.

## App Store edition
```bash
xcodebuild build -project Transflo.xcodeproj -scheme "TransfloForMac App Store" -configuration AppStore -destination 'generic/platform=macOS'
```

Builds the sandboxed edition (ad-hoc signed locally). Run it from the build folder to try the sandbox: it asks for
folder access on the first drop from each folder. Release steps are in [APP_STORE.md](APP_STORE.md).

## DMG installer
```bash
./scripts/build-dmg.sh
```

```bash
./scripts/build-dmg.sh --app /path/to/Transflo.app
```

- **Output:** writes `build/releases/Transflo-<version>-<architecture>.dmg` and never overwrites an existing one. `--output-dir` changes the location.
- **Look:** an illustrated installer window (title, arrow, hint) on Transflo's dark brand background. Finder keeps disk-image backgrounds fixed, so it looks the same in light and dark mode.
- **Python:** needed for Finder layout metadata. The two pinned dependencies in `scripts/dmg/requirements.txt` install into a temporary environment and are removed afterwards. Set `TRANSFLO_DMG_PYTHON` to reuse an interpreter that already has them.
- **Contents:** the installer carries the license, the third-party notices and the ffmpeg build info, with local paths removed.

For full releases (cask, notes, notarization), see [RELEASING.md](RELEASING.md).

## Layout
| Path | What |
|---|---|
| `TransfloForMac/` | Mac app target: DesignSystem (tokens, `App*` primitives and components), Presentation (MVVM + Coordinators), DI, localization (en/ar). Shared folders are compiled into mobile through `MobileShared` |
| `TransfloMobile/` | iPhone and iPad app target: touch DesignSystem, iOS platform adapters, Presentation, `MobileContainer` |
| `TransfloShare/` | The Share extension; reuses `TransfloMobile/` except `App/` |
| `Packages/TransfloDomain` | Pure Swift entities, use cases and protocols, plus `TransfloDomainTestSupport` doubles |
| `Packages/TransfloData` | Catalogs, conversion and tool engines (ImageIO, AVFoundation, PDFKit, Vision, ffmpeg, iWork), file actions |
| `Packages/TransfloSystem` | macOS integration: drag monitor, hotkey, pasteboard, terminals, AirDrop, login item, notifications |
| `scripts/` | Bootstrap, LGPL ffmpeg build, DMG and release |
| `docs/ARCHITECTURE.md` | Folder map, shared code between Mac and mobile, layers, persistence and test isolation |

## Continuous integration

`.github/workflows/ci.yml` runs on pull requests, pushes to `main`, and manual dispatch.
It uses the macOS 26 arm64 image's default Xcode (26 or newer), validates the workflow,
lints Swift, scans Git history for secrets, and builds the pinned LGPL media helpers.
Only helper binaries and build provenance are cached, keyed by the toolchain, build
script and source checksums; Xcode build products are never restored from cache.

Package tests run serially to avoid contention between encoders. App unit and native
UI tests run in separate steps with one desktop worker. Pull requests run Fast;
`main` and manual runs also run Extended, without repeating Fast tests. Optional iWork Automation
checks remain local and opt-in, as documented above.

The final step builds an ad-hoc-signed Release DMG and a Homebrew cask without
publishing them. Download **Transflo-arm64-review-build** from the run to inspect them.
Logs and `.xcresult` bundles are uploaded even on failure and retained for seven days.
No signing certificates, notarization credentials or write permissions are needed.
