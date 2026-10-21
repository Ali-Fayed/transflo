import TransfloDomain

/// Builds the ffmpeg arguments that join several clips into one: videos are scaled and padded
/// to the first clip's frame, clips without sound get silence, and everything is concatenated.
enum MergePlan {
    /// - Returns: Input and filter arguments up to (not including) the output encoding and path.
    static func arguments(inputs: [(path: String, info: MediaInfo)], format: String) -> [String]? {
        guard inputs.count >= 2, let encoding = FFmpegArguments.output(for: FormatID(format)) else { return nil }
        let isVideo = FFmpegToolArguments.videoFormats.contains(format)
        var arguments = inputs.flatMap { ["-i", $0.path] }
        var audioSources: [String] = []
        var silentIndex = inputs.count
        for (index, input) in inputs.enumerated() {
            if input.info.hasAudio {
                audioSources.append("[\(index):a]")
            } else {
                let duration = String(input.info.duration ?? 1)
                arguments += ["-f", "lavfi", "-t", duration, "-i", "anullsrc=r=48000:cl=stereo"]
                audioSources.append("[\(silentIndex):a]")
                silentIndex += 1
            }
        }
        var filters: [String] = []
        var segments = ""
        for index in inputs.indices {
            filters.append("\(audioSources[index])aresample=48000,aformat=channel_layouts=stereo[a\(index)]")
            if isVideo {
                filters.append("[\(index):v]\(frame(of: inputs[0].info))[v\(index)]")
                segments += "[v\(index)][a\(index)]"
            } else {
                segments += "[a\(index)]"
            }
        }
        let outputs = isVideo ? "[v][a]" : "[a]"
        filters.append("\(segments)concat=n=\(inputs.count):v=\(isVideo ? 1 : 0):a=1\(outputs)")
        arguments += ["-filter_complex", filters.joined(separator: ";")]
        arguments += (isVideo ? ["-map", "[v]"] : []) + ["-map", "[a]"]
        return arguments + FFmpegToolArguments.withoutVideoFilters(encoding)
    }

    /// Scale-to-fit, pad and frame-rate normalization to the first clip's geometry (even sizes).
    private static func frame(of first: MediaInfo) -> String {
        let width = ((first.width ?? 1280) / 2) * 2
        let height = ((first.height ?? 720) / 2) * 2
        let rate = first.frameRate.map { String(format: "%.3f", $0) } ?? "30"
        return "scale=\(width):\(height):force_original_aspect_ratio=decrease,"
            + "pad=\(width):\(height):(ow-iw)/2:(oh-ih)/2,setsar=1,fps=\(rate),format=yuv420p"
    }
}
