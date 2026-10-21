#if os(macOS)
import Foundation
import TransfloDomain

/// Measures each source at the requested targets, then supplies the measured second pass.
enum LoudnessProcessor {
    static func filter(_ target: LoudnessSettings) -> String {
        "loudnorm=I=\(target.integrated):TP=\(target.truePeak):LRA=\(target.range)"
    }

    static func measure(_ source: URL, target: LoudnessSettings, ffmpeg: URL) async throws(JobError)
        -> LoudnessMeasurement {
        guard target.isValid else { throw .unsupported }
        let errors = Collector()
        let status = await ProcessRunner.run(executable: ffmpeg,
            arguments: ["-hide_banner", "-nostdin", "-i", source.path, "-vn", "-sn", "-dn",
                        "-af", filter(target) + ":print_format=json", "-f", "null", "-"],
            onStdoutLine: { _ in }, onStderrLine: errors.append)
        if Task.isCancelled { throw .cancelled }
        guard status == 0 else { throw .failed }
        let text = errors.lines.joined(separator: "\n")
        guard let start = text.range(of: "{", options: .backwards),
              let end = text.range(of: "}", range: start.lowerBound..<text.endIndex),
              let values = try? JSONDecoder().decode([String: String].self,
                from: Data(text[start.lowerBound..<end.upperBound].utf8)),
              let integrated = values["input_i"].flatMap(Double.init),
              let peak = values["input_tp"].flatMap(Double.init),
              let range = values["input_lra"].flatMap(Double.init),
              let threshold = values["input_thresh"].flatMap(Double.init),
              let offset = values["target_offset"].flatMap(Double.init) else { throw .failed }
        let result = LoudnessMeasurement(integrated: integrated, truePeak: peak, range: range,
                                         threshold: threshold, offset: offset)
        // Digital silence produces -inf; do not pretend it can be normalized to audible sound.
        guard result.isFinite else { throw .nothingFound }
        return result
    }

    static func arguments(_ target: LoudnessSettings, measured: LoudnessMeasurement, format: String) -> [String]? {
        guard target.isValid, measured.isFinite, let audio = FFmpegToolArguments.audioCodec(for: format) else {
            return nil
        }
        let prefix = filter(target)
        let second = prefix + ":measured_I=\(measured.integrated):measured_TP=\(measured.truePeak)"
            + ":measured_LRA=\(measured.range):measured_thresh=\(measured.threshold)"
            + ":offset=\(measured.offset):linear=true"
        let video: [String]
        if FFmpegToolArguments.videoFormats.contains(format) { video = ["-c:v", "copy"] } else { video = ["-vn"] }
        return video + ["-af", second, "-ar", "48000"] + audio
    }
}
#endif
