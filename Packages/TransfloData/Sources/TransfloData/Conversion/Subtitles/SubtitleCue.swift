/// One timed caption. Times are milliseconds from the start.
struct SubtitleCue: Equatable, Sendable {
    let start: Int
    let end: Int
    let text: String
}
