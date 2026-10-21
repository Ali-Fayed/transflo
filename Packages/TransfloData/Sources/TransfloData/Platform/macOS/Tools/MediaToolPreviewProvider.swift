#if os(macOS)
import Foundation
import TransfloDomain

/// Editor previews: ffprobe and a frame grab for video and audio; images and PDFs as on iOS.
public struct MediaToolPreviewProvider: ToolPreviewProviding {
    static let thumbnailLongEdge = StillToolPreviewProvider.thumbnailLongEdge

    private let stills = StillToolPreviewProvider()
    private let ffmpeg: URL?
    private let ffprobe: URL?

    public init(ffmpeg: URL?, ffprobe: URL?) {
        self.ffmpeg = ffmpeg
        self.ffprobe = ffprobe
    }

    public func preview(of url: URL, format: FormatDescriptor?) async -> ToolPreview {
        switch format?.family {
        case .video, .audio:
            guard let ffprobe, let info = try? await FFprobe.info(binary: ffprobe, file: url) else { return .empty }
            let thumbnail = info.hasVideo ? await frame(of: url, at: min(1, (info.duration ?? 0) / 10)) : nil
            return ToolPreview(width: info.width, height: info.height, duration: info.duration, pageCount: nil,
                               thumbnail: thumbnail, frameRate: info.frameRate)
        default:
            return await stills.preview(of: url, format: format)
        }
    }

    public func frame(of url: URL, at seconds: Double) async -> Data? {
        guard let ffmpeg, let workspace = try? TemporaryWorkspace() else { return nil }
        defer { workspace.remove() }
        let output = workspace.url.appendingPathComponent("frame.png")
        let scale = "scale='min(iw\\,\(Self.thumbnailLongEdge))':-2"
        let arguments = ["-hide_banner", "-nostdin", "-loglevel", "error", "-ss", MediaEditArguments.seconds(seconds),
                         "-i", url.path, "-frames:v", "1", "-update", "1", "-vf", scale, output.path]
        let status = await ProcessRunner.run(
            executable: ffmpeg, arguments: arguments, onStdoutLine: { _ in }, onStderrLine: { _ in }
        )
        guard status == 0 else { return nil }
        if let data = try? Data(contentsOf: output) { return data }
        guard let ffprobe, let info = try? await FFprobe.info(binary: ffprobe, file: url),
              let duration = info.duration, duration > 0, seconds >= duration,
              let step = MediaEditArguments.snapshot(url.path, format: "mp4", at: seconds, duration: duration)
        else { return nil }
        let tailStatus = await ProcessRunner.run(
            executable: ffmpeg,
            arguments: ["-hide_banner", "-nostdin", "-loglevel", "error"] + step.arguments
                + ["-vf", scale, output.path],
            onStdoutLine: { _ in }, onStderrLine: { _ in }
        )
        return tailStatus == 0 ? try? Data(contentsOf: output) : nil
    }

    public func adjusted(_ thumbnail: Data, with adjustments: ImageAdjustments) async -> Data? {
        await stills.adjusted(thumbnail, with: adjustments)
    }

    public func pageThumbnails(of url: URL) async -> [Data] {
        await stills.pageThumbnails(of: url)
    }

    public func waveform(of url: URL) async -> Data? {
        guard let ffmpeg, let workspace = try? TemporaryWorkspace() else { return nil }
        defer { workspace.remove() }
        let output = workspace.url.appendingPathComponent("waveform.png")
        let status = await ProcessRunner.run(executable: ffmpeg,
            arguments: ["-hide_banner", "-nostdin", "-loglevel", "error", "-i", url.path,
                        "-filter_complex", "aformat=channel_layouts=mono,showwavespic=s=1000x120:colors=0x4AB5A6",
                        "-frames:v", "1", "-update", "1", output.path],
            onStdoutLine: { _ in }, onStderrLine: { _ in })
        return status == 0 ? try? Data(contentsOf: output) : nil
    }

    public func pagePreview(of url: URL, index: Int) async -> ToolPreview {
        await stills.pagePreview(of: url, index: index)
    }
}
#endif
