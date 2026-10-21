@preconcurrency import AVFoundation
import Foundation
import TransfloDomain

/// Runs one `AVAssetExportSession` into a private staging file and publishes it to `destination`
/// only when it completes, reporting progress and honoring cancellation.
enum AVMediaExport {
    static func export(
        _ asset: AVAsset,
        preset: String,
        fileType: AVFileType,
        to destination: URL,
        configure: (AVAssetExportSession) -> Void = { _ in },
        progress: @escaping @Sendable (Double) -> Void
    ) async throws(JobError) {
        let workspace = try TemporaryWorkspace(parent: destination.deletingLastPathComponent())
        defer { workspace.remove() }
        let staged = workspace.url.appendingPathComponent("export").appendingPathExtension(destination.pathExtension)
        guard let session = AVAssetExportSession(asset: asset, presetName: preset) else { throw .unsupported }
        configure(session)
        session.shouldOptimizeForNetworkUse = true
        let handle = AVExportHandle(session)
        let monitoring = Task {
            while !Task.isCancelled {
                progress(min(0.95, max(0, Double(handle.session.progress))))
                try? await Task.sleep(for: .milliseconds(200))
            }
        }
        defer { monitoring.cancel() }
        do {
            try await withTaskCancellationHandler {
                try Task.checkCancellation()
                if #available(iOS 18, macOS 15, *) {
                    try await handle.session.export(to: staged, as: fileType)
                } else {
                    handle.session.outputURL = staged
                    handle.session.outputFileType = fileType
                    await handle.session.export()
                    guard handle.session.status == .completed else { throw JobError.failed }
                }
            } onCancel: { handle.session.cancelExport() }
        } catch {
            throw Task.isCancelled ? .cancelled : .failed
        }
        monitoring.cancel()
        try ToolOutputPublisher.publish(staged, to: destination, isCancelled: { Task.isCancelled })
        progress(1)
    }

    /// The best preset that writes `fileType` for `asset`: passthrough when the streams allow it.
    static func preset(for asset: AVAsset, fileType: AVFileType, reencode: String) async -> String {
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) else {
            return reencode
        }
        let types = await withCheckedContinuation { continuation in
            session.determineCompatibleFileTypes { continuation.resume(returning: $0) }
        }
        return types.contains(fileType) ? AVAssetExportPresetPassthrough : reencode
    }
}

// @unchecked: the session is configured on one task; progress reads and cancelExport are the only
// operations from another.
private final class AVExportHandle: @unchecked Sendable {
    let session: AVAssetExportSession

    init(_ session: AVAssetExportSession) { self.session = session }
}
