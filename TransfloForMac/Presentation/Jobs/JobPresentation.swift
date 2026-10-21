import Foundation
import TransfloDomain

/// Maps job state to what the HUD shows.
enum JobPresentation {
    static func ring(for state: JobState) -> AppProgressRing.Status {
        switch state {
        case .queued: .progress(0)
        case .running(let fraction): .progress(fraction)
        case .succeeded: .success
        case .failed: .failure
        }
    }

    /// Title key plus format arguments.
    static func title(for record: JobRecord) -> (key: L10nKey, arguments: [String]) {
        switch record.state {
        case .queued, .running:
            if case .format(let format) = record.option.kind {
                return (.hudConverting, [format.displayName])
            }
            return (.hudWorking, [])
        case .succeeded where record.originalWithinTarget:
            return (.hudWithinTarget, [])
        case .succeeded(let outputs):
            return (successTitle(for: record.option, outputs: outputs), [])
        case .failed(let error) where !error.completedOutputs.isEmpty:
            return (.jobPartialFailure, [String(error.completedOutputs.count)])
        case .failed(.nothingFound):
            return (nothingFoundMessage(for: record.option), [])
        case .failed(.unsupported) where isAction(record.option):
            return (.errorActionUnavailable, [])
        case .failed(let error):
            return (message(for: error), [])
        }
    }

    /// The status line in the Jobs window: like the HUD title, minus "click to show" (the row has
    /// its own Show in Finder button).
    static func listStatus(for record: JobRecord) -> AppTextContent {
        let title = title(for: record)
        let listKeys: [L10nKey: L10nKey] = [.hudDone: .jobDone, .hudMoved: .jobMoved]
        if let key = listKeys[title.key] { return .key(key) }
        return title.arguments.isEmpty ? .key(title.key) : .formatted(title.key, title.arguments)
    }

    /// What VoiceOver says when a job ends: "Convert to PNG finished: photo.heic", or why it failed.
    /// Cancelled and unfinished jobs say nothing.
    static func announcement(for record: JobRecord, localizer: Localizer) -> String? {
        let operation = localizer.string(operation(for: record.option))
        switch record.state {
        case .succeeded:
            let files = localizer.string(JobRow(record).files)
            return localizer.string(.announceDone, arguments: [operation, files])
        case .failed(.cancelled), .queued, .running:
            return nil
        case .failed:
            return localizer.string(.announceFailed, arguments: [operation, localizer.string(listStatus(for: record))])
        }
    }

    /// What the job does, independent of its state: "Convert to PNG", "Compress", "Move".
    static func operation(for option: WheelOption) -> AppTextContent {
        switch option.kind {
        case .format(let format): .formatted(.jobConvertTo, [format.displayName])
        case .tool(let tool): .key(WheelPresentation.toolLabels[tool] ?? .wheelTools)
        case .action(let action): .key(WheelPresentation.label(for: action))
        case .recipe(let recipe): .verbatim(recipe.name)
        }
    }

    static func message(for error: JobError) -> L10nKey {
        if error == .multipleFrames { return .errorMultipleFrames }
        if error == .incompatibleSelection { return .errorIncompatibleSelection }
        return standardMessage(for: error)
    }

    private static func standardMessage(for error: JobError) -> L10nKey {
        switch error {
        case .sourceMissing: .errorSourceMissing
        case .destinationUnavailable, .destinationOccupied: .errorDestinationUnavailable
        case .failed: .errorFailed
        case .unsupported: .errorUnsupported
        case .cancelled: .errorCancelled
        case .automationDenied: .errorAutomationDenied
        case .nothingFound: .errorNothingFound
        case .targetUnreachable: .errorTargetUnreachable
        case .partialFailure(_, let cause): message(for: cause)
        default: .errorFailed
        }
    }

    private static func successTitle(for option: WheelOption, outputs: [URL]) -> L10nKey {
        switch option.kind {
        case .tool(.readCode) where outputs.isEmpty, .tool(.describeImage): .hudCopied
        case .action(let action): actionDone[action] ?? .hudDone
        default: .hudDone
        }
    }

    private static let actionDone: [ActionKind: L10nKey] = [
        .airDrop: .hudShared, .float: .hudAddedToShelf, .archive: .hudArchived,
        .copy: .hudFilesCopied, .move: .hudMoved,
        .copyPath: .hudPathCopied, .terminal: .hudOpenedInTerminal
    ]

    private static func isAction(_ option: WheelOption) -> Bool {
        if case .action = option.kind { true } else { false }
    }

    private static func nothingFoundMessage(for option: WheelOption) -> L10nKey {
        switch option.kind {
        case .tool(.readCode): .errorNoCodeFound
        case .tool(.extractText), .tool(.describeImage), .tool(.smartRename): .errorNoTextFound
        case .tool(.compress): .errorAlreadySmall
        default: .errorNothingFound
        }
    }
}
