/// Broad kind of content a format holds.
public enum FormatFamily: Sendable, Hashable, CaseIterable {
    case image
    case audio
    case video
    case document
    case presentation
    case spreadsheet
    case subtitle
    case archive
}
