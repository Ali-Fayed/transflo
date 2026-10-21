#if DEBUG
import AVFoundation
import UIKit

/// Disposable inputs for UI checks. Release builds never contain these launch-argument fixtures.
enum MobilePreviewInput {
    static func receive(using home: MobileHomeViewModel) async {
        let arguments = ProcessInfo.processInfo.arguments
        let kinds = ["video", "pdf", "audio", "input"]
        guard let kind = kinds.first(where: { arguments.contains("-transflo-mobile-preview-\($0)") }) else { return }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let source = try await fixture(kind, in: folder)
            var inputs = [source]
            if arguments.contains("-transflo-mobile-preview-batch") {
                let second = folder.appendingPathComponent("Second sample.\(source.pathExtension)")
                try FileManager.default.copyItem(at: source, to: second)
                inputs.append(second)
            }
            await home.receive(inputs)
        } catch { home.receiveFailed() }
    }

    private static func fixture(_ kind: String, in folder: URL) async throws -> URL {
        switch kind {
        case "video":
            let source = folder.appendingPathComponent("Transflo Sample.mp4")
            try await MobilePreviewVideo.write(to: source, duration: 12, poster: nil)
            return source
        case "pdf": return try pdf(in: folder)
        case "audio": return try audio(in: folder)
        default:
            let image = UIGraphicsImageRenderer(size: CGSize(width: 80, height: 60)).image { context in
                UIColor.systemTeal.setFill()
                context.fill(CGRect(x: 0, y: 0, width: 80, height: 60))
            }
            let name = "Transflo Sample \(UUID().uuidString.prefix(6)).jpg"
            let source = folder.appendingPathComponent(name)
            guard let data = image.jpegData(compressionQuality: 0.9) else { throw CocoaError(.fileWriteUnknown) }
            try data.write(to: source)
            return source
        }
    }

    private static func pdf(in folder: URL) throws -> URL {
        let source = folder.appendingPathComponent("Transflo Sample.pdf")
        try UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 400, height: 300))
            .writePDF(to: source) { context in
                for page in 1...2 {
                    context.beginPage()
                    UIColor.systemTeal.setFill()
                    context.fill(CGRect(x: 40, y: 40, width: 320, height: 220))
                    ("Transflo · Page \(page)" as NSString).draw(at: CGPoint(x: 60, y: 80), withAttributes: [
                        .font: UIFont.systemFont(ofSize: 30), .foregroundColor: UIColor.white
                    ])
                }
            }
        return source
    }

    private static func audio(in folder: URL) throws -> URL {
        let source = folder.appendingPathComponent("Transflo Sample.wav")
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 132_300),
              let samples = buffer.floatChannelData?[0] else { throw CocoaError(.fileWriteUnknown) }
        buffer.frameLength = 132_300
        for index in 0..<132_300 {
            samples[index] = Float(sin(Double(index) * 2 * .pi * 440 / 44_100) * 0.1)
        }
        let file = try AVAudioFile(forWriting: source, settings: format.settings)
        try file.write(from: buffer)
        return source
    }
}
#endif
