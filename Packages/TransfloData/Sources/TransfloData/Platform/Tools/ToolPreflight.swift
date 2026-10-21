import Foundation
import ImageIO
import PDFKit
import TransfloDomain

/// Validate the complete selection before the first output is published.
enum ToolPreflight {
    static func images(_ items: [ToolItem], tool: ToolKind) throws(JobError) {
        for item in items {
            if tool == .editMetadata, item.format?.id.rawValue == "webp" { throw .unsupported }
            guard FileManager.default.fileExists(atPath: item.url.path) else { throw .sourceMissing }
            guard tool != .readCode else { continue }
            guard let source = CGImageSourceCreateWithURL(item.url as CFURL, nil) else { throw .failed }
            guard CGImageSourceGetCount(source) == 1 else { throw .multipleFrames }
        }
    }

    static func pdfs(_ items: [ToolItem], settings: ToolSettings) throws(JobError) {
        for item in items {
            if BlockingWork.isCancelled { throw .cancelled }
            let document = try PDFKitEngine.open(item.url)
            switch settings {
            case .pages(let indices):
                guard !indices.isEmpty, indices.allSatisfy({ (0..<document.pageCount).contains($0) }) else {
                    throw .incompatibleSelection
                }
            case .splitPages(let every):
                guard every > 0, document.pageCount > every else { throw .incompatibleSelection }
            case .pageAnnotations(let pages): try validatePages(Array(pages.keys), count: document.pageCount)
            case .pageRedactions(let pages): try validatePages(Array(pages.keys), count: document.pageCount)
            default: break
            }
        }
    }

    private static func validatePages(_ pages: [Int], count: Int) throws(JobError) {
        guard !pages.isEmpty, pages.allSatisfy({ (0..<count).contains($0) }) else { throw .incompatibleSelection }
    }

    static func media(_ items: [ToolItem], settings: ToolSettings, ffprobe: URL?) async throws(JobError) {
        for item in items {
            if Task.isCancelled { throw .cancelled }
            guard FileManager.default.fileExists(atPath: item.url.path) else { throw .sourceMissing }
            switch settings {
            case .trim, .split, .snapshot, .snapshotJPEG, .bleep, .normalize, .channels:
                #if os(macOS)
                guard let ffprobe else { throw .unsupported }
                try validate(settings, info: await FFprobe.info(binary: ffprobe, file: item.url))
                #else
                throw .unsupported
                #endif
            default: break
            }
        }
    }

    private static func validate(_ settings: ToolSettings, info: MediaInfo) throws(JobError) {
        switch settings {
        case .trim, .split, .snapshot, .snapshotJPEG, .bleep:
            try validateTimeline(settings, info: info)
        case .normalize(let target):
            guard target.isValid, info.hasAudio else { throw .incompatibleSelection }
        case .channels(let mix):
            guard info.hasAudio, mix != .right || (info.audioChannels ?? 0) >= 2 else {
                throw .incompatibleSelection
            }
        default: break
        }
    }

    private static func validateTimeline(_ settings: ToolSettings, info: MediaInfo) throws(JobError) {
        let duration = info.duration ?? 0
        switch settings {
        case let .trim(start, end):
            guard start.isFinite, end.isFinite, start >= 0, end > start, end <= duration + 0.001 else {
                throw .incompatibleSelection
            }
        case .split(let cuts):
            let sorted = cuts.sorted()
            guard !sorted.isEmpty, sorted.allSatisfy({ $0.isFinite && $0 > 0.05 && $0 < duration - 0.05 }),
                  zip(sorted, sorted.dropFirst()).allSatisfy({ $1 - $0 >= 0.05 }) else {
                throw .incompatibleSelection
            }
        case .snapshot(let time), .snapshotJPEG(let time, _):
            guard time.isFinite, time >= 0, duration > 0, time <= duration + 0.001 else {
                throw .incompatibleSelection
            }
        case .bleep(let spans):
            guard info.hasAudio, !spans.isEmpty,
                  spans.allSatisfy({ $0.start.isFinite && $0.end.isFinite && $0.start >= 0
                      && $0.end > $0.start && $0.end <= duration + 0.001 }) else { throw .incompatibleSelection }
        default: break
        }
    }
}
