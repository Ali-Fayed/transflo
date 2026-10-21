# App Store

The iPhone and iPad app is live as **Transflo: File Converter**
([App Store, id 6824513929](https://apps.apple.com/us/app/transflo-file-converter/id6824513929)): free,
Utilities, iOS and iPadOS 17 or later. The Mac edition below shares the same bundle identifier, so both
are one App Store record (universal purchase).

## Mac App Store edition

Transflo ships in two editions built from the same code:

| | Direct (DMG, Homebrew) | Mac App Store |
|---|---|---|
| Build | `TransfloForMac` scheme, Release | `TransfloForMac App Store` scheme, `AppStore` configuration |
| Sandbox | No | Yes (`TransfloForMac/Resources/TransfloAppStore.entitlements`) |
| Saving beside originals | Anywhere you can write | In folders you allow once (the app asks, then remembers) |
| Finder-selection shortcut (⌥⌘↩) | Yes | No; **Open in Transflo** in the right-click menu works |
| Pages, Keynote, Numbers conversions | Yes | No (Apple Events aren't allowed) |
| Terminal action | Yes | No |
| Updates | Daily check + Check for Updates; opens the GitHub release | Daily check + Check for Updates; opens the App Store, which installs it |

The switches live in `AppEdition` (TransfloDomain) and `EditionFactory` (the app's DI). The `APP_STORE`
compilation condition selects the edition; nothing else in the code checks for it.

## One-time setup (developer account)
1. **Certificates:** in Xcode › Settings › Accounts › Manage Certificates, add *Apple Distribution* and
   *Mac Installer Distribution* (shown as "3rd Party Mac Developer Installer").
2. **App ID:** `com.transflo.app` (already registered with the app record in App Store Connect).
3. **Profile:** in the developer portal create a *Mac App Store* provisioning profile for `com.transflo.app`,
   download it and double-click to install. Note its name.
4. **Category:** Productivity (set in `Info.plist` as `public.app-category.productivity`).

## Each release
```bash
TRANSFLO_TEAM_ID=<TEAMID> TRANSFLO_APPSTORE_PROFILE="<profile name>" ./scripts/release-appstore.sh
```

```bash
TRANSFLO_UPLOAD=1 TRANSFLO_TEAM_ID=<TEAMID> TRANSFLO_APPSTORE_PROFILE="<profile name>" ./scripts/release-appstore.sh
```

The first writes a signed `.pkg` to `build/releases/appstore/` (upload it with Transporter). The second uploads
directly, using the account Xcode is signed in to. Then pick the build on the version page in App Store Connect
and submit it for review.

## Listing copy
Character limits are checked: subtitle 30, promotional text 170, keywords 100, description 4000. The copy
describes only what the App Store edition does (no Terminal action, no Pages/Keynote/Numbers conversions,
no Finder-selection shortcut).

- **Name:** Transflo
- **Subtitle:** Convert files at your cursor
- **Keywords:** converter,heic,jpg,png,webp,pdf,compress,resize,crop,mp4,mp3,video,audio,image,batch,rename,airdrop
- **Description:** covers grouped tools, Recipes, watch folders, archives and on-device intelligence.

- **What's New (1.0.0):** First release. Convert, edit and compress files from a wheel at your cursor.

- **Support URL:** https://transfloformac.ali-fayed.com/support
- **Privacy Policy URL:** https://transfloformac.ali-fayed.com/privacy
- **Privacy:** App Privacy › *Data Not Collected*. The only network request is the update check, which asks the
  public App Store lookup service (`itunes.apple.com/lookup`) for Transflo's version number; it sends no user data.
  The `com.apple.security.network.client` entitlement exists only for this. Apple doesn't allow apps to update
  themselves (guideline 2.4.5(vii)), so Transflo only opens its App Store page.
- **Screenshots:** ten 2880 × 1800 opaque PNGs covering conversion, grouped tools, image editing, PDF, media, Recipes, archives, compression, customization and Arabic.

## Review notes (paste into App Review Information)
Transflo is a menu-bar app. To try it: drag any image from Finder and, while still dragging, tap Shift; a wheel
appears under the pointer. Drop the image on PNG. The first drop from a folder shows a folder chooser asking
permission to save next to the file (App Sandbox); choose Allow. The result appears beside the original. Settings
and Getting Started are in the menu-bar icon's menu.


## Release safety verification

The app bundles `PrivacyInfo.xcprivacy` for its own preferences and file timestamps. Privacy Policy
and Support are also available from the menu bar. CI builds the App Store configuration separately
and checks the embedded manifest and the app/helper sandbox entitlements. An ad-hoc build is a
compilation and packaging check; it does not validate App Store distribution signing or approval.

Before submission, install the signed distribution build through TestFlight and verify:

- Drag a file from Desktop, Documents, Downloads, an external drive, and a read-only folder. Grant
  only the requested folder and confirm successful output or a clear permission error.
- Move to a newly selected destination, quit, reopen, and move again using that recent destination.
  Also revoke/remove a granted folder and confirm Transflo asks again rather than losing the job.
- Convert media with the bundled helpers from outside the app container, including paths with
  spaces and non-Latin characters. Confirm helper access under the distribution sandbox.
- Cancel conversion, PDF split/merge, Rename, and Move. Completed results must remain accessible;
  partial batches show their completed count and expose Show in Finder.
- Test on macOS 14 as well as the current macOS version. ImageIO's available encoders vary by OS.
- Review App Store Connect's privacy report against the bundled manifest, the listing, and the
  public privacy policy; validate the signed archive and installer before uploading.

Oversized or malformed inputs are rejected rather than silently truncated. Current safeguards
include a 100,000-row/16,384-column/1,000,000-cell expanded sheet budget, 2,000 pages per PDF,
64 MiB text input, 32 MiB XML parts, and 1 GiB/20,000-entry archive extraction budget. Archive
budgets are checked during helper execution and after it exits; they are not a filesystem quota.
Wide spreadsheet PDF exports span additional pages horizontally. The Extract Text tool reads text layers and performs OCR page by page for scanned PDFs.
