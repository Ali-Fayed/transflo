import AVFoundation
import Foundation
import TransfloDomain

/// Decodes any Apple-readable audio file and re-encodes it as M4A (AAC), WAV or AIFF (16-bit PCM).
enum AudioFileTranscoder {
    static let frameChunk: AVAudioFrameCount = 65_536
    static let aacBitRate = 192_000

    static func transcode(
        _ request: ConversionRequest,
        isCancelled: () -> Bool,
        progress: @Sendable (Double) -> Void
    ) throws(JobError) {
        try OutputFile.write(to: request.destination) { staged throws(JobError) in
            let inner = ConversionRequest(source: request.source, destination: staged,
                                          sourceFormat: request.sourceFormat, targetFormat: request.targetFormat)
            try transcodeStaged(inner, isCancelled: isCancelled, progress: progress)
        }
    }

    private static func transcodeStaged(
        _ request: ConversionRequest,
        isCancelled: () -> Bool,
        progress: @Sendable (Double) -> Void
    ) throws(JobError) {
        let input: AVAudioFile
        do {
            input = try AVAudioFile(forReading: request.source)
        } catch {
            throw .failed
        }
        let format = input.processingFormat
        guard input.length > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameChunk) else { throw .failed }
        let settings = outputSettings(for: request.targetFormat.id.rawValue, format: input.fileFormat)
        do {
            let output = try AVAudioFile(
                forWriting: request.destination,
                settings: settings,
                commonFormat: format.commonFormat,
                interleaved: format.isInterleaved
            )
            while input.framePosition < input.length {
                if isCancelled() { throw JobError.cancelled }
                try input.read(into: buffer, frameCount: frameChunk)
                try output.write(from: buffer)
                progress(Double(input.framePosition) / Double(input.length))
            }
        } catch let error as JobError {
            throw error
        } catch {
            throw FileManager.default.isWritableFile(atPath: request.destination.deletingLastPathComponent().path)
                ? .failed : .destinationUnavailable
        }
    }

    static func outputSettings(for target: String, format: AVAudioFormat) -> [String: Any] {
        let base: [String: Any] = [
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: format.channelCount
        ]
        switch target {
        case "m4a":
            return base.merging([AVFormatIDKey: kAudioFormatMPEG4AAC, AVEncoderBitRateKey: aacBitRate]) { $1 }
        default:
            return base.merging([
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: target == "aiff",
                AVLinearPCMIsNonInterleaved: false
            ]) { $1 }
        }
    }
}
