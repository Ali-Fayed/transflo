#if DEBUG
import AppKit
import CoreImage
import CoreText
import ImageIO
import TransfloData
import TransfloDomain

/// Scratch inputs for the debug-only preview launch arguments (UI-test screenshots).
///
/// Nonisolated so callers write the files off the main thread (ImageIO warns about HEIC
/// encoding there); see `inBackground`.
nonisolated enum PreviewScratchFiles {
    static let pageCount = 4
    static let imageCount = 4

    /// `make(for:in:)` on a background thread, creating `folder` first.
    static func inBackground(for tool: ToolKind, in folder: URL) async -> [URL] {
        await Task.detached(priority: .userInitiated) {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            return make(for: tool, in: folder)
        }.value
    }

    /// A PDF for page tools, several images for multi-file tools, one image otherwise.
    static func make(for tool: ToolKind, in folder: URL) -> [URL] {
        switch tool {
        case .trim, .changeSpeed, .snapshot, .bleep, .split:
            let video = folder.appendingPathComponent("Sample clip.mp4")
            writeVideo(to: video)
            return [video]
        case .normalize, .channels:
            let audio = folder.appendingPathComponent("Stereo recording.wav")
            writeAudio(to: audio)
            return [audio]
        case .readCode:
            let code = folder.appendingPathComponent("Website code.png")
            writeCode(to: code)
            return [code]
        case .merge:
            return (1...2).map { index in
                let pdf = folder.appendingPathComponent("Document \(index).pdf")
                writePDF(to: pdf)
                return pdf
            }
        case .reorganizePages, .extractPages:
            let pdf = folder.appendingPathComponent("Quarterly report.pdf")
            writePDF(to: pdf)
            return [pdf]
        case .collage, .rename, .imagesToPDF:
            return (1...imageCount).map { index in
                let url = folder.appendingPathComponent("Holiday photo \(index).heic")
                writeHEIC(to: url)
                return url
            }
        default:
            let url = folder.appendingPathComponent("Holiday photo.heic")
            writeHEIC(to: url)
            return [url]
        }
    }

    /// A short local test clip gives media editors real timing and frame previews.
    private static func writeVideo(to url: URL) {
        guard let binary = FFmpegEngine.bundledBinary(in: .main) else { return }
        let process = Process()
        process.executableURL = binary
        let source = ProcessInfo.processInfo.arguments.contains(LaunchArgument.screenshotCapture)
            ? marketingVideoSource : "testsrc2=size=640x360:rate=24"
        process.arguments = ["-y", "-f", "lavfi", "-i", source,
                             "-f", "lavfi", "-i", "sine=frequency=440:sample_rate=44100", "-t", "12",
                             "-c:v", "mpeg4", "-pix_fmt", "yuv420p", "-c:a", "aac", url.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do { try process.run(); process.waitUntilExit() } catch { return }
    }

    /// An original animated landscape, rather than color bars, for promotional captures.
    private static var marketingVideoSource: String {
        let sun = "lt(hypot(X-440,Y-100),36)"
        let hill = "gt(Y,230+40*sin(X/140+T/3))"
        return "color=c=0xb7e0d6:s=640x360:r=24,geq="
            + "r='if(\(sun),242,if(\(hill),31,183))':"
            + "g='if(\(sun),193,if(\(hill),92,224))':"
            + "b='if(\(sun),78,if(\(hill),79,214))'"
    }

    private static func writeAudio(to url: URL) {
        guard let binary = FFmpegEngine.bundledBinary(in: .main) else { return }
        let process = Process()
        process.executableURL = binary
        process.arguments = ["-y", "-f", "lavfi", "-i",
                             "aevalsrc=0.1*sin(2*PI*440*t)|0.1*sin(2*PI*880*t):s=48000:d=3", url.path]
        process.standardOutput = FileHandle.nullDevice; process.standardError = FileHandle.nullDevice
        do { try process.run(); process.waitUntilExit() } catch { return }
    }

    private static func writeCode(to url: URL) {
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return }
        filter.setValue(Data("https://transfloformac.ali-fayed.com/".utf8), forKey: "inputMessage")
        guard let code = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 12, y: 12)) else { return }
        let padded = code.composited(over: CIImage(color: .white).cropped(to: code.extent.insetBy(dx: -48, dy: -48)))
        guard let image = CIContext().createCGImage(padded, from: padded.extent),
              let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)
        else { return }
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)
    }

    /// A 640×480 picture: a teal disc on a transparent background.
    static func writeHEIC(to url: URL) {
        let context = CGContext(
            data: nil, width: 640, height: 480, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        context?.setFillColor(CGColor(red: 0.07, green: 0.65, blue: 0.58, alpha: 1))
        context?.fillEllipse(in: CGRect(x: 170, y: 90, width: 300, height: 300))
        guard let image = context?.makeImage(),
              let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.heic" as CFString, 1, nil)
        else { return }
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)
    }

    /// Letter-size pages, each showing its number.
    private static func writePDF(to url: URL) {
        var box = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let context = CGContext(url as CFURL, mediaBox: &box, nil) else { return }
        for page in 1...pageCount {
            context.beginPDFPage(nil)
            let line = CTLineCreateWithAttributedString(NSAttributedString(
                string: "\(page)", attributes: [.font: NSFont.boldSystemFont(ofSize: 220)]
            ))
            context.textPosition = CGPoint(x: 230, y: 320)
            CTLineDraw(line, context)
            context.endPDFPage()
        }
        context.closePDF()
    }
}
#endif
