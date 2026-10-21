/// What ffprobe reports about a media file.
struct MediaInfo: Equatable, Sendable {
    let duration: Double?
    let width: Int?
    let height: Int?
    let hasVideo: Bool
    let hasAudio: Bool
    let audioChannels: Int?
    let frameRate: Double?
    /// Container-level tags such as `title` or `artist`.
    let tags: [String: String]
}
