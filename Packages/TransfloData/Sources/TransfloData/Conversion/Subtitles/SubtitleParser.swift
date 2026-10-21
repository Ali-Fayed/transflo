import Foundation

/// Reads SRT and WebVTT cues. Tolerant of BOMs, CRLF, missing indices, hour-less VTT
/// timestamps, cue settings and NOTE/STYLE/REGION blocks.
enum SubtitleParser {
    static func cues(from text: String) -> [SubtitleCue] {
        let normalized = text
            .replacingOccurrences(of: "\u{FEFF}", with: "")
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        return normalized.components(separatedBy: "\n\n").compactMap(cue(from:))
    }

    private static func cue(from block: String) -> SubtitleCue? {
        var lines = block.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        guard let timingIndex = lines.firstIndex(where: { $0.contains("-->") }) else { return nil }
        let parts = lines[timingIndex].components(separatedBy: "-->")
        let endStamp = parts.count == 2
            ? parts[1].split(separator: " ", omittingEmptySubsequences: true).first.map(String.init)
            : nil
        guard let start = milliseconds(parts.first), let end = milliseconds(endStamp) else { return nil }
        lines.removeSubrange(0...timingIndex)
        let text = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : SubtitleCue(start: start, end: end, text: text)
    }

    /// `HH:MM:SS,mmm`, `HH:MM:SS.mmm` or `MM:SS.mmm`.
    static func milliseconds(_ stamp: String?) -> Int? {
        guard let stamp = stamp?.trimmingCharacters(in: .whitespaces), !stamp.isEmpty else { return nil }
        let unified = stamp.replacingOccurrences(of: ",", with: ".")
        let clock = unified.split(separator: ".", maxSplits: 1)
        guard clock.count == 2, let millis = Int(clock[1].prefix(3)), clock[1].count <= 3 else { return nil }
        let fields = clock[0].split(separator: ":").map { Int($0) }
        guard fields.allSatisfy({ $0 != nil }) else { return nil }
        let values = fields.compactMap { $0 }
        switch values.count {
        case 3: return ((values[0] * 60 + values[1]) * 60 + values[2]) * 1000 + millis
        case 2: return (values[0] * 60 + values[1]) * 1000 + millis
        default: return nil
        }
    }
}
