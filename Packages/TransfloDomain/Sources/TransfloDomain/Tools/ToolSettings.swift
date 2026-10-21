import Foundation

/// Parameters for one tool run (or an action's choice, such as Move's folder). Instant tools use
/// `defaults(for:)`; editors supply their own.
public enum ToolSettings: Sendable, Hashable {
    case compress(CompressionGoal)
    /// Explicit image compression controls; nil long edge keeps the source dimensions for presets.
    case compressImage(goal: CompressionGoal, maximumLongEdge: Int?)
    /// Clockwise quarter turns (1...3) and mirroring.
    case rotate(quarterTurns: Int, flipHorizontal: Bool, flipVertical: Bool)
    /// Exact output size in pixels.
    case resize(width: Int, height: Int)
    case crop(NormalizedRect)
    case adjust(ImageAdjustments)
    /// Seconds from the start.
    case trim(start: Double, end: Double)
    /// Playback rate: 0.5 is half speed, 2 double speed (0.25...4).
    case changeSpeed(Double)
    /// Cut points in seconds; each segment becomes its own file.
    case split(points: [Double])
    /// PDF: a new file every `every` pages.
    case splitPages(every: Int)
    /// Seconds into the video.
    case snapshot(at: Double)
    case snapshotJPEG(at: Double, quality: Int)
    case annotate([Annotation])
    /// Boxes painted solid black; PDF pages carrying a box are flattened so hidden text is gone.
    case redact([NormalizedRect])
    /// `#RRGGBB` behind transparent pixels.
    case addBackground(BackgroundStyle)
    /// Grid of images: columns, gap in pixels, background `#RRGGBB`.
    case collage(columns: Int, spacing: Int, background: String)
    /// Spans replaced by a 1 kHz tone.
    case bleep([TimeSpan])
    /// Zero-based page indices in their new order; omitted pages are dropped.
    case pages([Int])
    /// New values; an empty string clears the field.
    case metadata([MetadataField: String])
    /// `{name}` is the original name, `{n}` a counter starting at `start`.
    case rename(pattern: String, start: Int)
    /// Smart Rename: the new base name for each file, in order (extensions are kept).
    case renameTo([String])
    /// Move: the folder chosen before the job runs.
    case destination(URL)
    case collageLayout(CollageSettings)
    case assemble(AssemblySettings)
    case removeBackground(BackgroundRemovalSettings)
    case normalize(LoudnessSettings)
    case channels(ChannelMix)
    case copyCodes([String])
    case removeMetadata(Set<MetadataCategory>)
    case pageAnnotations([Int: [Annotation]])
    case pageRedactions([Int: [NormalizedRect]])
    /// Tools without parameters.
    case none

    /// Preserves existing callers of the simple solid-background tool.
    public static func addBackground(color: String) -> ToolSettings {
        .addBackground(BackgroundStyle(fill: .solid(color)))
    }

    public static let speedRange = 0.25...4.0

    /// The settings an instant (drop-and-go) run uses. Interactive tools get theirs from an editor.
    public static func defaults(for tool: ToolKind) -> ToolSettings {
        switch tool {
        case .compress: .compress(.medium)
        case .rotate: .rotate(quarterTurns: 1, flipHorizontal: false, flipVertical: false)
        default: .none
        }
    }
}
