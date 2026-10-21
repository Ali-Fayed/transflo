/// File tools offered on the Tools wheel.
public enum ToolKind: String, Sendable, Hashable, CaseIterable {
    case compress
    case resize
    case crop
    case rotate
    case adjust
    case annotate
    case redact
    case removeBackground
    case addBackground
    case readCode
    case imagesToPDF
    case collage
    case trim
    case changeSpeed
    case split
    case merge
    case snapshot
    case mute
    case normalize
    case bleep
    case channels
    case reorganizePages
    case extractPages
    case editMetadata
    case removeMetadata
    case rename
    /// Recognized text from images and PDFs, saved as a .txt beside each.
    case extractText
    /// A short alt-text description of each image, copied to the clipboard (on-device model, macOS 26).
    case describeImage
    /// Descriptive names suggested from each image's content, reviewed before renaming (macOS 26).
    case smartRename
    /// Twice the resolution, on the GPU.
    case upscale
    /// Unpacks an archive into a new folder beside the source.
    case extractArchive
}
