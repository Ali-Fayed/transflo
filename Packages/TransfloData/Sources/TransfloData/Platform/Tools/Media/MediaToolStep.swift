/// One ffmpeg run within a tool: everything between `ffmpeg` and the output path.
struct MediaToolStep: Equatable {
    let arguments: [String]
    /// Output extension, or `nil` to keep the source's.
    let fileExtension: String?
}
