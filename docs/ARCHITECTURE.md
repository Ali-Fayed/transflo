# Architecture

Transflo is one product on two platforms: a native macOS menu-bar utility, and a universal iPhone and
iPad app with a Share extension. Both are Swift 6 and SwiftUI. The Mac uses AppKit for floating panels,
drag observation and system integration. Three local Swift packages hold the logic both platforms share.

## Repository layout

```
Packages/
  TransfloDomain/      pure models, settings contracts, use cases and protocols (no UI frameworks)
  TransfloData/        conversion and tool engines, JSON catalogs, repositories
  TransfloSystem/      macOS adapters: drag pasteboard, hotkeys, Finder, AirDrop, login items
TransfloForMac/        the Mac app target (product name "Transflo")
  App/                 entry point, app delegate, menu bar
  DI/                  AppContainer, feature factories, EditionFactory
  DesignSystem/        App* components, semantic tokens, Liquid Glass      (shared with mobile)
  Localization/        English and Arabic strings                          (shared with mobile)
  Intents/             Shortcuts and Siri actions                          (shared with mobile)
  Presentation/        feature views, @Observable view models, coordinators
    Wheel/ Jobs/ Appearance/                                               (mostly shared with mobile)
    Editors/ Settings/                                                     (selected files shared)
    MenuBar/ Shelf/ Keyboard/ WatchFolders/ Updates/ Welcome/              (Mac only)
TransfloMobile/        the iPhone and iPad app target
  App/                 TransfloMobileApp, app delegate, intent registration, background time
  DI/                  MobileContainer and its factories
  DesignSystem/        touch components: Home tiles, paired grid, swipe actions, trim range
  Platform/            iOS adapters: Photos, audio session, item providers, share revealer
  Presentation/        Home, Files, Activity (Jobs), Settings, action picker, Editors, Export
TransfloShare/         the "Convert with Transflo" Share extension
TransfloTests/ TransfloUITests/                  Mac unit and UI tests
TransfloMobileTests/ TransfloMobileUITests/      mobile unit and UI tests
scripts/               bootstrap, ffmpeg build, DMG and release
```

The Mac folder is named `TransfloForMac` so Mac-only code is easy to tell apart; the app it builds is
still called Transflo.

## Targets and shared code

`project.yml` (XcodeGen) defines the app-side targets:

| Target | Platform | Sources |
|---|---|---|
| `TransfloForMac` | macOS 14+ | `TransfloForMac/` and all three packages |
| `TransfloMobile` | iOS and iPadOS 17+ | `TransfloMobile/`, `TransfloForMac/Intents`, the `MobileShared` template |
| `TransfloShare` | iOS app extension | `TransfloShare/`, `TransfloMobile/` without `App/`, the `MobileShared` template |
| Test targets | per platform | the test folders above |

The `MobileShared` template compiles chosen Mac folders into the mobile targets instead of copying
them: Localization, the DesignSystem, Appearance, wheel option resolution, Jobs, the markup editors and
the settings view models. Mac-only files inside those folders (the drag panel, trackpad haptics,
floating HUDs, the shortcut recorder and the App Store folder-access prompt) are excluded by name in
the template, each with a comment saying why. Mobile links `TransfloDomain` and `TransfloData`, never
`TransfloSystem`.

Where a new file goes:

- It works on both platforms: put it in `TransfloForMac` or a package, and list it in `MobileShared`.
- It needs UIKit, Photos or the audio session: put it in `TransfloMobile`.
- It needs `UIApplication.shared`: put it in `TransfloMobile/App` behind a protocol, because the Share
  extension can't use it; the extension receives a no-op.

## Layers

- `Packages/TransfloDomain`: pure models, settings contracts and use cases.
- `Packages/TransfloData`: file conversion engines, catalogs and persistent repositories.
- `Packages/TransfloSystem`: macOS adapters for input, Finder, login items and notifications.
- `Presentation`: feature view models, views and coordinators, per platform.
- `DesignSystem`: localized UI components, semantic colors and layout tokens. Screens compose `App*`
  components only.
- `DI`: the composition root and feature factories. `AppContainer` on Mac, `MobileContainer` on iPhone
  and iPad.

Dependencies are constructed in the container and passed into features through initializers.
Business logic is tested through hand-written protocol doubles without opening windows or modifying
user files. Native UI tests cover the visible flows separately.

## How each platform starts a job

**Mac.** `DragMonitor` notices a file drag and the wheel key. `WheelCoordinator` asks
`ResolveWheelOptionsUseCase` what applies to every dragged file. The petal you drop on becomes a job
in `JobCenter`, which runs it with bounded concurrency and publishes the result beside the original.

**iPhone and iPad.** Files arrive from Photos, Files, drag and drop, Open In or the Share extension.
`MobileProvisionalImport` (Unit of Work) holds the import until the user commits an action, so a
cancelled editor leaves nothing behind. The searchable Convert and Tools picker uses the same
`ResolveWheelOptionsUseCase`. The job is scheduled through `ImportCommittingScheduler` (Decorator).
Results land in the app's Documents folder, visible in Files, then open the save or share flow.
`MobileAudioSession` and `MobileBackgroundTime` adapt the iOS audio session and background time
behind protocols. `MobileMarkupEditorFactory` builds the shared markup editors for touch.

## Named patterns

- **Strategy:** conversion and tool engines, and the job presenter behind `JobHUDPresenting` (the result
  disc on Mac, a banner on mobile).
- **Registry:** `ConversionCatalog`.
- **Decorator:** wheel visibility, App Store folder access, and `ImportCommittingScheduler` on mobile.
- **Unit of Work:** `MobileProvisionalImport`.
- **Adapter:** `TransfloSystem` on Mac; `MobileAudioSession`, `MobileBackgroundTime` and the Photos saver
  on mobile.
- **Repository:** settings and job history.
- **Factory:** both containers, editions and the mobile markup editors.
- **Coordinator:** wheel, editors and windows on Mac; navigation on mobile.

## Editions
The Mac target builds two editions. The direct edition (DMG, Homebrew) has every feature. The `AppStore`
build configuration adds the `APP_STORE` condition and the sandbox entitlements. `AppEdition` (domain)
states what each edition may do, and `EditionFactory` (DI) is the only place that acts on it. It:

- drops the iWork engines and the Terminal action;
- skips the Finder-selection hotkey and update checks;
- wraps the job scheduler in `FolderAccessJobScheduler`, which asks for folder access before results
  are written.

See [APP_STORE.md](APP_STORE.md). The iPhone and iPad app ships as a single App Store edition.

## Preferences

Appearance and language use dedicated UserDefaults keys. Accent color, wheel size, surface style and
reduced motion are encoded as one validated `InterfaceCustomization` value, on both platforms. The
composition root reads saved values before creating windows or scenes. Edits persist immediately and
update the shared presentation style. Closing a window or quitting the app does not reset preferences.

Debug UI tests use a unique `TransfloUITests.*` preferences suite. They keep that suite across app
relaunches within a test, terminate their app processes, and remove the suite afterwards. Release
builds ignore this testing override. Tests must never reset the installed application's normal
preferences.

## Mac Settings layout

Each tab measures its natural content height independently of its scroll viewport, and the window
follows the selected tab's preferred size:

- Tall tabs are bounded and scroll: Customization, and Wheel with its full Convert checklist.
- Short tabs (General, Keys and Output) shrink to their content.
- Only the selected page is mounted, so hidden native pickers don't keep stale layers during resizing.
- Appearance and wheel-size controls reserve a stable width while the preview changes.
- Compression and file naming share Output.

Conditional fields, language changes and larger text must remain readable.

## Catalog and fixtures

The JSON catalogs declare supported formats and tools; each platform filters them to the engines it
ships. Fixture tests validate conversions, outputs and error handling with synthetic inputs generated
at test time. Third-party media, user documents and generated build artifacts do not belong in the
source tree.
