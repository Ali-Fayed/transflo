/// Extracts the input duration (stderr banner) and encoded time (`-progress` key/value lines).
enum FFmpegProgressParser {
    /// Seconds from a line like `  Duration: 00:01:02.50, start: …`.
    static func duration(fromStderrLine line: String) -> Double? {
        guard let range = line.range(of: "Duration: ") else { return nil }
        let stamp = line[range.upperBound...].prefix { $0 != "," }
        return seconds(fromTimestamp: String(stamp))
    }

    /// Seconds from `out_time_us=1234567` (also emitted as `out_time_ms`, which is microseconds too).
    static func encodedSeconds(fromProgressLine line: String) -> Double? {
        let parts = line.split(separator: "=", maxSplits: 1)
        guard parts.count == 2, parts[0] == "out_time_us" || parts[0] == "out_time_ms",
              let micros = Double(parts[1]), micros >= 0 else { return nil }
        return micros / 1_000_000
    }

    static func seconds(fromTimestamp stamp: String) -> Double? {
        let fields = stamp.split(separator: ":").compactMap { Double($0) }
        guard fields.count == 3 else { return nil }
        return fields[0] * 3600 + fields[1] * 60 + fields[2]
    }
}
