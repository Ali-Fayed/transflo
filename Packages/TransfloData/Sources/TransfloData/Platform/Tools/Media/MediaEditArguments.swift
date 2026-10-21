import TransfloDomain

/// ffmpeg steps for the editor-driven media tools: Resize, Crop, Trim, Change speed, Split, Snapshot.
enum MediaEditArguments {
    /// The ffmpeg steps for an editor tool's settings; `info` is the probed source where needed.
    static func steps(
        for settings: ToolSettings, source: String, format: String, info: MediaInfo?
    ) -> [MediaToolStep]? {
        if case let .snapshotJPEG(time, quality) = settings {
            guard (1...100).contains(quality),
                  let png = snapshot(source, format: format, at: time, duration: info?.duration) else { return nil }
            let level = max(2, 31 - quality * 29 / 100)
            return [MediaToolStep(arguments: png.arguments + ["-q:v", String(level)], fileExtension: "jpg")]
        }
        return standardSteps(for: settings, source: source, format: format, info: info)
    }

    private static func standardSteps(
        for settings: ToolSettings, source: String, format: String, info: MediaInfo?
    ) -> [MediaToolStep]? {
        let step: MediaToolStep?
        switch settings {
        case let .resize(width, height): step = resize(source, format: format, width: width, height: height)
        case let .crop(rect): step = info.flatMap { crop(source, format: format, rect: rect, info: $0) }
        case let .trim(start, end): step = trim(source, format: format, start: start, end: end)
        case let .changeSpeed(factor):
            step = changeSpeed(source, format: format, factor: factor, hasAudio: info?.hasAudio ?? false)
        case let .split(points):
            return split(source, format: format, points: points, duration: info?.duration ?? 0)
        case let .snapshot(time): step = snapshot(source, format: format, at: time, duration: info?.duration)
        case let .bleep(spans): step = bleep(source, format: format, spans: spans, hasVideo: info?.hasVideo ?? false)
        case let .metadata(values): step = metadata(source, values: values)
        default: step = nil
        }
        return step.map { [$0] }
    }

    static func resize(_ source: String, format: String, width: Int, height: Int) -> MediaToolStep? {
        guard FFmpegToolArguments.videoFormats.contains(format), width > 1, height > 1,
              let output = FFmpegArguments.output(for: FormatID(format)) else { return nil }
        let scale = "scale=\(width - width % 2):\(height - height % 2)"
        let encoding = FFmpegToolArguments.mergingVideoFilters([scale], into: output)
        return MediaToolStep(arguments: ["-i", source] + encoding, fileExtension: nil)
    }

    static func crop(_ source: String, format: String, rect: NormalizedRect, info: MediaInfo) -> MediaToolStep? {
        guard FFmpegToolArguments.videoFormats.contains(format), let width = info.width, let height = info.height,
              let output = FFmpegArguments.output(for: FormatID(format)) else { return nil }
        let pixels = rect.pixels(width: width, height: height, even: true)
        let crop = "crop=\(pixels.width):\(pixels.height):\(pixels.x):\(pixels.y)"
        let encoding = FFmpegToolArguments.mergingVideoFilters([crop], into: output)
        return MediaToolStep(arguments: ["-i", source] + encoding, fileExtension: nil)
    }

    static func trim(_ source: String, format: String, start: Double, end: Double) -> MediaToolStep? {
        guard end > start, start >= 0, let output = encoding(for: format) else { return nil }
        return MediaToolStep(
            arguments: ["-i", source, "-ss", seconds(start), "-to", seconds(end)] + output, fileExtension: nil
        )
    }

    static func changeSpeed(_ source: String, format: String, factor: Double, hasAudio: Bool) -> MediaToolStep? {
        guard ToolSettings.speedRange.contains(factor), let output = encoding(for: format) else { return nil }
        var arguments = ["-i", source]
        if FFmpegToolArguments.videoFormats.contains(format) {
            arguments += FFmpegToolArguments.mergingVideoFilters(["setpts=PTS/\(seconds(factor))"], into: output)
        } else {
            arguments += output
        }
        if hasAudio { arguments += ["-filter:a", tempoChain(factor)] }
        return MediaToolStep(arguments: arguments, fileExtension: nil)
    }

    /// One step per segment between consecutive cut points (and the ends).
    static func split(_ source: String, format: String, points: [Double], duration: Double) -> [MediaToolStep]? {
        let cuts = points.filter { $0 > 0.05 && $0 < duration - 0.05 }.sorted()
        guard !cuts.isEmpty else { return nil }
        let bounds = [0] + cuts + [duration]
        return zip(bounds, bounds.dropFirst()).compactMap { trim(source, format: format, start: $0, end: $1) }
    }

    static func snapshot(_ source: String, format: String, at time: Double, duration: Double? = nil) -> MediaToolStep? {
        guard FFmpegToolArguments.videoFormats.contains(format), time >= 0 else { return nil }
        if let duration, duration > 0, time >= duration {
            // Decode the tail and update the same image for each frame, leaving the final frame.
            // Seeking exactly to EOF otherwise succeeds without writing anything.
            return MediaToolStep(
                arguments: ["-sseof", "-1", "-i", source, "-update", "1"], fileExtension: "png"
            )
        }
        return MediaToolStep(
            arguments: ["-ss", seconds(time), "-i", source, "-frames:v", "1", "-update", "1"], fileExtension: "png"
        )
    }

    /// Mutes each span and mixes in a 1 kHz tone there; video is copied untouched.
    static func bleep(_ source: String, format: String, spans: [TimeSpan], hasVideo: Bool) -> MediaToolStep? {
        guard !spans.isEmpty, spans.allSatisfy({ $0.start.isFinite && $0.end.isFinite
            && $0.start >= 0 && $0.end > $0.start }),
              let audio = FFmpegToolArguments.audioCodec(for: format) else { return nil }
        // aeval evaluates every sample and keeps the source channel layout. Frame-based
        // volume enable expressions can leave original speech audible at either boundary.
        let windows = spans.map {
            "between(t\\,\(preciseSeconds($0.start))\\,\(preciseSeconds($0.end)))"
        }.joined(separator: "+")
        let graph = "[0:a]aeval=exprs='if(\(windows)\\,0.0375*sin(2*PI*1000*t)\\,val(ch))':c=same[a]"
        let video = hasVideo ? ["-map", "0:v", "-c:v", "copy"] : []
        return MediaToolStep(arguments: ["-i", source, "-filter_complex", graph] + video + ["-map", "[a]"] + audio,
                             fileExtension: nil)
    }

    /// Sets (or clears, with an empty value) container tags; streams are copied.
    static func metadata(_ source: String, values: [MetadataField: String]) -> MediaToolStep? {
        guard !values.isEmpty else { return nil }
        let keys: [MetadataField: String] = [.title: "title", .author: "artist", .comment: "comment"]
        let tags = values.sorted { $0.key.rawValue < $1.key.rawValue }
            .flatMap { ["-metadata", "\(keys[$0.key] ?? $0.key.rawValue)=\($0.value)"] }
        return MediaToolStep(arguments: ["-i", source, "-map", "0", "-c", "copy"] + tags, fileExtension: nil)
    }

    /// `atempo` accepts 0.5...2 per stage, so larger changes chain stages.
    static func tempoChain(_ factor: Double) -> String {
        var remaining = factor
        var stages: [String] = []
        while remaining > 2 {
            stages.append("atempo=2")
            remaining /= 2
        }
        while remaining < 0.5 {
            stages.append("atempo=0.5")
            remaining /= 0.5
        }
        stages.append("atempo=\(seconds(remaining))")
        return stages.joined(separator: ",")
    }

    private static func encoding(for format: String) -> [String]? {
        let isMedia = FFmpegToolArguments.videoFormats.union(FFmpegToolArguments.audioFormats).contains(format)
        return isMedia ? FFmpegArguments.output(for: FormatID(format)) : nil
    }

    private static func preciseSeconds(_ value: Double) -> String {
        String(format: "%.9f", locale: nil, value)
    }

    /// Fixed-point text ffmpeg accepts in any locale.
    static func seconds(_ value: Double) -> String {
        String(format: "%.3f", locale: nil, value)
    }
}
