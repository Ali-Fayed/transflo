import TransfloDomain

/// ffmpeg output arguments for the instant media tools. Codecs stay LGPL-only, as for conversions.
enum FFmpegToolArguments {
    static let videoFormats: Set<String> = ["mp4", "mov", "mkv", "webm", "avi", "wmv"]
    static let audioFormats: Set<String> = ["mp3", "m4a", "wav", "flac", "ogg", "opus", "aiff", "wma"]
    static let compressibleFormats: Set<String> = ["mp4", "mov", "mkv", "webm", "mp3", "m4a", "ogg", "opus", "wma"]
    static let loudness = "loudnorm=I=-16:TP=-1.5:LRA=11"

    /// Re-encodes at a lower quality; video is also capped at 1920 (medium) or 1280 (strong) wide.
    static func compress(_ format: String, level: CompressionLevel) -> [String]? {
        let step = CompressionLevel.allCases.firstIndex(of: level) ?? 1
        switch format {
        case "mp4", "mov", "mkv":
            let quality = ["55", "45", "40"][step]
            let audio = ["128k", "96k", "64k"][step]
            // "Smaller file" uses hardware HEVC, much smaller at the same quality; `hvc1` keeps MP4 and
            // MOV playable in QuickTime, Photos and Safari.
            let codec = step == 2 ? ["-c:v", "hevc_videotoolbox"] + (format == "mkv" ? [] : ["-tag:v", "hvc1"])
                                  : ["-c:v", "h264_videotoolbox"]
            return codec + ["-q:v", quality, "-pix_fmt", "yuv420p", "-vf", capWidth(step),
                            "-c:a", "aac", "-b:a", audio] + (format == "mp4" ? ["-movflags", "+faststart"] : [])
        case "webm":
            return ["-c:v", "libvpx-vp9", "-crf", ["34", "40", "46"][step], "-b:v", "0", "-row-mt", "1",
                    "-vf", capWidth(step), "-c:a", "libopus", "-b:a", ["96k", "64k", "48k"][step]]
        case "mp3": return ["-vn", "-c:a", "libmp3lame", "-b:a", ["192k", "128k", "96k"][step]]
        case "m4a": return ["-vn", "-c:a", "aac", "-b:a", ["160k", "128k", "96k"][step]]
        case "ogg": return ["-vn", "-c:a", "libvorbis", "-q:a", ["4", "3", "1"][step]]
        case "opus": return ["-vn", "-c:a", "libopus", "-b:a", ["96k", "64k", "48k"][step]]
        case "wma": return ["-vn", "-c:a", "wmav2", "-b:a", ["128k", "96k", "64k"][step]]
        default: return nil
        }
    }

    private static func capWidth(_ step: Int) -> String {
        let width = ["iw", "min(iw\\,1920)", "min(iw\\,1280)"][step]
        return "scale='\(width)':-2"
    }

    /// Rotation/flip filters merged into the format's normal video encoding.
    static func rotate(_ format: String, quarterTurns: Int, flipHorizontal: Bool, flipVertical: Bool) -> [String]? {
        guard videoFormats.contains(format), let output = FFmpegArguments.output(for: FormatID(format)) else {
            return nil
        }
        var filters: [String] = []
        switch ((quarterTurns % 4) + 4) % 4 {
        case 1: filters.append("transpose=1")
        case 2: filters += ["transpose=1", "transpose=1"]
        case 3: filters.append("transpose=2")
        default: break
        }
        if flipHorizontal { filters.append("hflip") }
        if flipVertical { filters.append("vflip") }
        return mergingVideoFilters(filters, into: output)
    }

    static func mute(_ format: String) -> [String]? {
        videoFormats.contains(format) ? ["-map", "0:v", "-an", "-c:v", "copy"] : nil
    }

    /// EBU R128 loudness to −16 LUFS; video streams are copied untouched.
    static func normalize(_ format: String) -> [String]? {
        guard let audio = audioCodec(for: format) else { return nil }
        let video = videoFormats.contains(format) ? ["-c:v", "copy"] : ["-vn"]
        return video + ["-af", loudness, "-ar", "48000"] + audio
    }

    static func mono(_ format: String, mix: ChannelMix = .mix) -> [String]? {
        guard audioFormats.contains(format), let audio = audioCodec(for: format) else { return nil }
        let channel = mix == .left ? 0 : 1
        let selection = mix == .mix ? [] : ["-af", "pan=mono|c0=c\(channel)"]
        return ["-vn"] + selection + ["-ac", "1"] + audio
    }

    static let stripMetadata = ["-map", "0", "-map_metadata", "-1", "-map_chapters", "-1", "-c", "copy"]

    /// The audio encoder a container normally carries.
    static func audioCodec(for format: String) -> [String]? {
        switch format {
        case "mp4", "mov", "mkv": ["-c:a", "aac", "-b:a", "160k"]
        case "webm": ["-c:a", "libopus", "-b:a", "128k"]
        case "avi": ["-c:a", "libmp3lame", "-q:a", "4"]
        case "wmv": ["-c:a", "wmav2", "-b:a", "160k"]
        default: FFmpegArguments.output(for: FormatID(format)).map { Array($0.drop { $0 == "-vn" }) }
        }
    }

    /// `output` with its `-vf` chain extended by `filters` (or a new `-vf` added).
    static func mergingVideoFilters(_ filters: [String], into output: [String]) -> [String] {
        guard !filters.isEmpty else { return output }
        var arguments = output
        if let index = arguments.firstIndex(of: "-vf"), index + 1 < arguments.count {
            arguments[index + 1] = (filters + [arguments[index + 1]]).joined(separator: ",")
        } else {
            arguments += ["-vf", filters.joined(separator: ",")]
        }
        return arguments
    }

    /// The format's encoding without any `-vf` (for `-filter_complex` graphs).
    static func withoutVideoFilters(_ output: [String]) -> [String] {
        guard let index = output.firstIndex(of: "-vf"), index + 1 < output.count else { return output }
        var arguments = output
        arguments.removeSubrange(index...(index + 1))
        return arguments
    }
}
