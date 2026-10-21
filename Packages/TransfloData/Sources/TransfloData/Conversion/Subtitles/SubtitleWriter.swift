/// Writes cues as SRT, WebVTT or plain text.
enum SubtitleWriter {
    enum Style {
        case srt
        case vtt
        case plainText
    }

    static func text(for cues: [SubtitleCue], style: Style) -> String {
        switch style {
        case .srt:
            cues.enumerated().map { index, cue in
                "\(index + 1)\n\(stamp(cue.start, separator: ",")) --> \(stamp(cue.end, separator: ","))\n\(cue.text)\n"
            }.joined(separator: "\n")
        case .vtt:
            "WEBVTT\n\n" + cues.map { cue in
                "\(stamp(cue.start, separator: ".")) --> \(stamp(cue.end, separator: "."))\n\(cue.text)\n"
            }.joined(separator: "\n")
        case .plainText:
            cues.map(\.text).joined(separator: "\n") + (cues.isEmpty ? "" : "\n")
        }
    }

    static func stamp(_ milliseconds: Int, separator: String) -> String {
        let total = max(0, milliseconds)
        let hours = total / 3_600_000
        let minutes = total / 60_000 % 60
        let seconds = total / 1000 % 60
        let millis = total % 1000
        return pad(hours, 2) + ":" + pad(minutes, 2) + ":" + pad(seconds, 2) + separator + pad(millis, 3)
    }

    private static func pad(_ value: Int, _ width: Int) -> String {
        let digits = String(value)
        return String(repeating: "0", count: max(0, width - digits.count)) + digits
    }
}
