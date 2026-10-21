# Wheel editor options

Transflo opens a focused editor for 26 of its 31 tools. Mute, Extract Text, Describe Image, Upscale and archive Extract run immediately. Edits create new output files; Rename changes filenames. When several files use the same settings, the dialog explains that its preview represents the first file. Compression calculates percentage budgets separately for each original file.

| Editor | Controls |
| --- | --- |
| Compress | Original file size; quality presets; maximum bytes per file; percentage of original size; original dimensions; 1280/1920/2560 px caps; custom longest edge from 1 to 16384 px for images. |
| Rotate | No rotation, 90° clockwise, 180°, 90° counterclockwise; horizontal and vertical mirroring for images/video; preview and reset. |
| Resize | Original dimensions; exact width/height; proportion lock; 25% and 50% shortcuts; custom 1–400% scale from the original; longest-edge fitting at 1280/1920/2560 px without enlarging; restore original size. |
| Crop | Draggable crop box; Free, Original, Square, 4:3, 16:9, 9:16, 3:4, 4:5, 3:2 and 2:3; exact pixel width/height; X/Y offsets; center crop; reset. |
| Adjust | Exposure, brightness, contrast, highlight recovery, shadow lift, warmth, tint, saturation, vibrance, sharpness, noise reduction and vignette; Black & White, Warm Portrait and Brighten Shadows presets; Original comparison; individual and global resets. |
| Add Background | Live composition preview; eight gradients; seven solid swatches and a native custom RGB color panel; Minimal, Balanced and Spacious compositions; padding, corners and shadow; nine canvas ratios; reset and retry. |
| Annotate | PDF page navigation with independent page edits and history; edited-page count; rectangle, arrow, pen and text; seven ink swatches and custom RGB color; thin/medium/thick weight; mark count; undo, redo and recoverable Clear. |
| Redact | PDF page navigation and per-page regions; solid black regions; region count; remove individual regions; undo, redo and recoverable Clear. |
| Collage | Export-rendered composition preview; source ordering and removal; exact cell dimensions; Fit/Fill; output pixel dimensions; Grid, Single Row and Single Column layouts; exact columns; gap from 0 to 200 pixels; solid/custom RGB background; image and row counts; reset. |
| Trim | Source playback, waveform and range audition; draggable in/out handles; exact start/end seconds; kept duration; First Half, Middle Half and Last Half selections; reset. |
| Change Speed | Source playback at the chosen rate and waveform; rate slider and precise rate field; 0.25×, 0.5×, 0.75×, 1.25×, 1.5×, 2× and 4× presets; resulting duration; reset to 1×. |
| Split | Source playback and waveform; per-part duration summary; equal media parts or custom cut points; add/remove sorted cut points; output-file count; pages-per-file grouping for PDFs; reset. |
| Snapshot | Source playback; frame stepping at the probed frame rate; PNG or JPEG with quality; frame preview; time slider; exact seconds; 0/25/50/75/100% shortcuts. The endpoint selects the final frame through the same backend path as preview/export. |
| Bleep | Source playback and waveform with selected-range audition; draggable audio interval; exact start/end seconds; add/remove intervals; next one-second interval; clear all; automatic joining of overlaps. |
| Reorganize PDF Pages | Page thumbnails; drag ordering; explicit move-up/down buttons; remove pages; reverse order; restore original order. |
| Extract PDF Pages | Thumbnail selection; individual pages and ranges such as `1-3, 5`; Arabic digits; odd/even pages; invert selection; Select All/None; selected-page count. Invalid range input retains the last valid selection. |
| Edit Metadata | Read-only inspection of detected fields; individual field clearing; title, author and multiline comment; filename context; restore original values; clear fields. Only changed fields are submitted. |
| Rename | Editable pattern; insert original-name/number tokens; Name + Number, Number + Name and Number Only templates; starting number; full selectable original/result filenames; reset. |

| Merge | Drag ordering, up/down controls, omission, reverse/reset, source previews, total duration/page count and first-source output-format explanation. |
| Images to PDF | Source ordering and omission; original-size/A4/Letter pages; landscape; margins; Fit/Fill; first-page layout preview using the export placement rules. |
| Remove Background | Full-source Vision analysis; original/result comparison; subject selection; feathering; transparent PNG or solid/custom background; rendered preview; reset/retry. |
| Normalize | Podcast/Streaming/Broadcast presets; custom LUFS, true-peak ceiling and loudness range; input measurement; measured two-pass export; source and processed audio audition. |
| Convert to Mono | Channel mix, left-only or right-only; source playback, waveform and processed audition; per-source channel validation. |
| Read QR/Barcode | Results view; selected-result copying; individual Copy; explicit HTTP(S) Open; Select All/None. Nothing opens automatically. |
| Remove Metadata | All-source inspection; descriptive/location/camera/other groups; selected field count; per-source field lists; structural/encoder-field explanation. |

## Format-specific behavior

- PDF compression uses the system reduction filter. Exact-size targets, percentages and image pixel caps are not offered for PDF files.
- PDF Rotate changes page rotation. Mirror controls are available for images/video, not PDFs.
- Annotation and redaction keep edits on their selected PDF pages. Edited redaction pages are flattened to remove covered text; other pages retain their original content.
- Bleep replaces selected audio with the existing 1 kHz tone. It does not offer unsupported frequency or volume settings.
- Media speed ranges from 0.25× to 4×. Splitting allows 2–20 equal parts or at most 19 custom cuts; points must stay away from the clip endpoints and one another.
- Snapshot writes one PNG or JPEG. Exact-endpoint selection uses the last frame.
- Rename preserves extensions and shows the generated filenames before the operation. Existing output collision handling still applies.

## Layout and accessibility

Long editor content scrolls independently of the title and primary action. Wrapping chip groups replace crowded tool/weight segments. Crop dimensions and coordinates are separate full-width rows. Rename previews wrap rather than putting long filenames into narrow side-by-side columns. English/light and Arabic/dark inventory checks cover every editor, including the top and bottom of long panels.

Conversion-format wedges and the five immediate tools execute directly. The other 26 tools have editors. File actions retain their dedicated behavior, such as Move's folder chooser and Float's shelf.

## Export safety

- Pixel-edit and assembly operations reject animated or multipage image sources rather than silently discarding frames. Originals remain available.
- PDF page selections and media time ranges are validated against every source before publishing batch outputs. Missing pages, out-of-range cuts and incompatible channels produce a specific error.
- Background and collage settings cannot be applied until the current preview finishes rendering.
- Cancelling an editor also cancels pending validation. A late validation result cannot start a job.
- Source lists measure their rows and shrink for short selections. Long panels scroll while keeping the primary action visible.
- ZIP, RAR, TAR and GZIP extraction publishes a new folder atomically beside each archive. Existing names are numbered, unsafe paths are rejected, and completed folders remain visible if a later batch item fails.
- Wheel tick sound and trackpad haptics are independently saved in Settings > General.
