#if DEBUG
import AVFoundation
import CoreGraphics
import CoreVideo
import Foundation

/// Disposable H.264 footage for simulator checks, excluded from Release builds.
nonisolated enum MobilePreviewVideo {
    static func write(to url: URL, duration: Int = 2, poster: CGImage? = nil) async throws {
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: 1280, AVVideoHeightKey: 720
        ])
        let adapter = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: 1280, kCVPixelBufferHeightKey as String: 720
        ])
        writer.add(input)
        guard writer.startWriting() else { throw CocoaError(.fileWriteUnknown) }
        writer.startSession(atSourceTime: .zero)
        for frame in 0..<(max(1, duration) * 6) {
            while !input.isReadyForMoreMediaData {
                try Task.checkCancellation()
                if writer.status == .failed { throw CocoaError(.fileWriteUnknown) }
                try await Task.sleep(for: .milliseconds(10))
            }
            var buffer: CVPixelBuffer?
            guard let pool = adapter.pixelBufferPool,
                  CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer) == kCVReturnSuccess,
                  let buffer else { throw CocoaError(.fileWriteUnknown) }
            CVPixelBufferLockBaseAddress(buffer, [])
            if let base = CVPixelBufferGetBaseAddress(buffer) {
                memset(base, Int32(40 + (frame % 12) * 12), CVPixelBufferGetDataSize(buffer))
                if let poster, let context = CGContext(data: base, width: 1280, height: 720,
                    bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) {
                    let zoom = 1 + Double(frame) / Double(max(1, duration) * 6) * 0.12
                    context.draw(poster, in: CGRect(x: -40 * zoom, y: -100 * zoom,
                                                   width: 1360 * zoom, height: 1020 * zoom))
                }
            }
            CVPixelBufferUnlockBaseAddress(buffer, [])
            guard adapter.append(buffer, withPresentationTime: CMTime(value: Int64(frame), timescale: 6)) else {
                throw CocoaError(.fileWriteUnknown)
            }
        }
        writer.endSession(atSourceTime: CMTime(value: Int64(max(1, duration)), timescale: 1))
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else { throw CocoaError(.fileWriteUnknown) }
    }
}
#endif
