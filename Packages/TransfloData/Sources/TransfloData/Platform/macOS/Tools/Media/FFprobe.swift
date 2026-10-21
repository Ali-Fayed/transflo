#if os(macOS)
import Foundation
import TransfloDomain

/// Reads stream and container facts with the bundled ffprobe.
enum FFprobe {
    static func info(binary: URL, file: URL) async throws(JobError) -> MediaInfo {
        let output = Collector()
        let status = await ProcessRunner.run(
            executable: binary,
            arguments: ["-v", "error", "-print_format", "json", "-show_streams", "-show_format", file.path],
            onStdoutLine: output.append,
            onStderrLine: { _ in }
        )
        guard status == 0 else { throw .failed }
        return try parse(Data(output.lines.joined(separator: "\n").utf8))
    }

    static func parse(_ json: Data) throws(JobError) -> MediaInfo {
        guard let dto = try? JSONDecoder().decode(FFprobeDTO.self, from: json) else { throw .failed }
        let streams = dto.streams ?? []
        let video = streams.first { $0.codecType == "video" }
        let audio = streams.first { $0.codecType == "audio" }
        return MediaInfo(
            duration: dto.format?.duration.flatMap(Double.init),
            width: video?.swapsDimensions == true ? video?.height : video?.width,
            height: video?.swapsDimensions == true ? video?.width : video?.height,
            hasVideo: video != nil,
            hasAudio: audio != nil,
            audioChannels: audio?.channels,
            frameRate: video?.averageFrameRate.flatMap(frameRate),
            tags: metadataTags(streams: streams, container: dto.format?.tags ?? [:])
        )
    }

    private static func metadataTags(streams: [FFprobeStreamDTO], container: [String: String]) -> [String: String] {
        var result: [String: String] = [:]
        for tags in streams.compactMap(\.tags) + [container] {
            for (key, value) in tags { result[key.lowercased()] = value }
        }
        return result
    }

    /// `"30000/1001"` → 29.97; `"0/0"` → nil.
    static func frameRate(_ fraction: String) -> Double? {
        let parts = fraction.split(separator: "/").compactMap { Double($0) }
        guard parts.count == 2, parts[1] > 0, parts[0] > 0 else { return nil }
        return parts[0] / parts[1]
    }
}
#endif
