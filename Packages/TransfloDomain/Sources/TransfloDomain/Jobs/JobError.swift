import Foundation

/// Why a wheel job did not produce its output.
public enum JobError: Error, Sendable, Equatable {
    /// A dragged file no longer exists.
    case sourceMissing
    /// No output could be written beside the original (permissions, read-only volume, name exhaustion).
    case destinationUnavailable
    /// Another file occupies the destination; it must never be removed during cleanup.
    case destinationOccupied
    /// The operation itself failed.
    case failed
    /// No available engine handles this file and target on this system.
    case unsupported
    /// The user or the system cancelled the job.
    case cancelled
    /// macOS blocked Transflo from controlling Pages, Keynote or Numbers (Automation privacy setting).
    case automationDenied
    /// The tool found nothing to act on (e.g. no QR code in the image).
    case nothingFound
    /// The requested byte budget cannot be reached within the safe encode limits.
    case targetUnreachable
    /// A single-frame tool must not silently discard animation or document frames.
    case multipleFrames
    /// At least one source lacks the requested pages, channels or timeline range.
    case incompatibleSelection
    /// Completed files remain available when a later batch item fails or is cancelled.
    indirect case partialFailure(completed: [URL], cause: JobError)

    public var completedOutputs: [URL] {
        if case .partialFailure(let completed, let cause) = self { return completed + cause.completedOutputs }
        return []
    }

    public var underlying: JobError {
        if case .partialFailure(_, let cause) = self { return cause.underlying }
        return self
    }
}
