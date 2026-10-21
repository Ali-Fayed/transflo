# iPhone and iPad feature comparison

Reviewed against the current source on 2026-10-21. The universal iPhone and iPad app targets
iOS/iPadOS 17 and later. It runs native Apple engines, so a few Mac formats that need the bundled
FFmpeg or iWork are Mac only.

## Available on mobile

| Area | Current implementation | Limits compared with Mac |
| --- | --- | --- |
| Import | Image and Video → Files or Photo Library; six Home types: Image, PDF, Audio, Video, Text and Document; incoming drag and drop, Open In and Share extension | No Home clipboard import or standalone subtitle category |
| Navigation | Native tabs, text-only leading titles, custom trailing close control, accent-aware category controls and first-run-only onboarding | Mac keeps its cursor wheel and global drag activation |
| Action selection | Searchable Convert/Tools lists, related tools and saved recipes, phone/tablet layouts, English/Arabic | Only options supported by the selected files are offered |
| Images | ImageIO conversions; compress, resize, crop, rotate/flip, adjust, background removal/fill, collage, metadata, QR reading, image-to-PDF, annotation and redaction | No ffmpeg WebP writer or SVG engine; animated inputs cannot use still-image editors |
| Audio | Native conversion plus trim, speed, split and merge; source playback | No ffmpeg-only formats, Normalize, Bleep or channel editing |
| Video | MP4/MOV conversion and compression; video-to-GIF and M4A soundtrack export; trim, speed, snapshot, mute, split and merge; inline/fullscreen source playback | No broad container conversions or Live Photo export |
| PDF | Text/image export; rotate, reorder, extract, split and merge; metadata, QR reading, per-page annotation/redaction | No Mac compression filter or broad office-format export |
| Archives | Not offered: the share sheet and Files app cover zipping | Mac keeps ZIP creation and ZIP, RAR, TAR and GZIP extraction |
| Intelligence | OCR and 2× upscale; image descriptions when the required Apple Intelligence features are available | Smart Rename's review flow is not exposed; device availability varies |
| Workspace | Files tab, real recently modified files on Home, Quick Look, sharing and deletion | No floating shelf, Finder services or Terminal actions |
| Activity | Live progress/cancellation and persistent earlier results, with sharing when outputs remain available | No mobile Undo or background job execution guarantees |
| Output settings | Best/Balanced/Smaller defaults and output naming style; new compression editors use the saved default | No custom byte or percentage budgets |
| Customization | Show/hide individual conversions and tools; show/hide all; recency/frequency ordering; accent, appearance, language, effects and haptics | No Mac wheel geometry or keyboard bindings |
| Recipes | Create, edit, reorder and delete recipes; Convert, Compress, Resize, Remove Metadata and Rename steps; matching saved recipes appear under Tools | No watch folders or recipe import/sync UI; steps must fit native mobile engines |
| Shortcuts and Siri | Convert Files, Compress Files and Run Recipe intents use the native mobile engines and saved output defaults | Siri invocation and system discovery require device validation; unsupported inputs must fail safely |

## Editing and saving

Apply starts processing after the editor dismisses. Source previews use bounded thumbnails; outputs
use the original imported data. Media previews start at the beginning, support sound and five-second
skip controls, and retain their position through fullscreen transitions. Trim uses one timeline with
two handles. Editing either handle resets playback to the new selection's beginning; the scrubber and
current/total times describe that selection, in `m:ss` (or `h:mm:ss` for longer recordings).
Speed previews also display the adjusted duration. Compression is applied on export.

Compatible image results offer Photo Library or Files. Other outputs open the system share sheet.
Multiple results queue until the current prompt closes. Cancelling keeps outputs in the workspace.
Imported files and outputs remain in the app's Documents folder and are visible through Files.
Already compressed videos may not become smaller. Photos saving uses add-only permission.

## Remaining gaps

- Mac-only document, spreadsheet, iWork and additional archive/media engines.
- Smart Rename review, Normalize, Bleep, channel editing and mobile Undo.
- Watch folders, recipe exchange and background-aware job recovery.
- The complete Mac compatibility browser and integration settings.

## Validation

Mobile checks cover image edits and dimensions, source preservation, PDF pages and metadata,
markup models, conversion saving, media exports and playback, persisted visibility/output settings,
and recipe persistence and availability. UI regressions cover navigation, input-source selection,
customization, recipe creation/use, markup on the second PDF page, trim/fullscreen behavior and output sharing.

Local continuation checks passed: the renamed Mac target builds and its 250 unit tests pass;
79 mobile unit tests pass. UI checks on Duo and iPad cover all six Home inputs, navigation,
media trim/fullscreen/export, Photos and Files saving, PDF markup on page two, recipes,
and persisted output/visibility preferences. Failing UI cases were retained in the initial logs;
targeted reruns passed after synchronizing the remote Files form and targeting the editor scroll area
and adaptive navigation correctly. These results do not establish distribution readiness.

Installed simulators include iOS 27.1 on iPhone Duo and iOS 27.0 on a 13-inch iPad Pro.
The minimum iOS 17 runtime remains unavailable; it cannot be counted as validated. A universal simulator
build checks both supported device families and the Share extension. Physical-device sound,
haptics, Apple Intelligence, memory pressure and background suspension still need hardware checks.
