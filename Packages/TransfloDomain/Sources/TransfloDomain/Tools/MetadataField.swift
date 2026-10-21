/// Editable metadata common to images, audio, video and PDFs.
public enum MetadataField: String, Sendable, Hashable, CaseIterable {
    case title
    case author
    case comment
}
