import Foundation
import Observation
import TransfloDomain

@Observable
final class AudioToolEditorViewModel: ToolEditorModel {
    let item: URL
    let tool: ToolKind
    var targets = LoudnessSettings()
    var mix = ChannelMix.mix
    private(set) var audition: Data?
    private(set) var previewing = false
    @ObservationIgnored private var auditionSettings: ToolSettings?
    var currentAudition: Data? { auditionSettings == settings ? audition : nil }
    private(set) var preview: ToolPreview = .empty
    private(set) var measurement: LoudnessMeasurement?
    private(set) var error: L10nKey?
    private(set) var measuring = false
    @ObservationIgnored private let format: FormatDescriptor?
    @ObservationIgnored let previews: any ToolPreviewProviding
    @ObservationIgnored private let inspector: (any ToolInspectionProviding)?

    init(
        item: URL,
        format: FormatDescriptor?,
        tool: ToolKind,
        previews: any ToolPreviewProviding,
        inspector: (any ToolInspectionProviding)?
    ) {
        self.item = item; self.format = format; self.tool = tool; self.previews = previews; self.inspector = inspector
    }
    var settings: ToolSettings? {
        guard let duration = preview.duration, duration.isFinite, duration > 0, !measuring else { return nil }
        if tool == .channels { return .channels(mix) }
        guard targets.isValid, measurement != nil else { return nil }
        return .normalize(targets)
    }
    func load() async {
        preview = await previews.preview(of: item, format: format)
        if tool == .normalize { await measure() }
    }
    func measure() async {
        guard targets.isValid else { return }
        measuring = true; error = nil
        do {
            guard let inspector else { throw JobError.unsupported }
            measurement = try await inspector.loudness(of: item, settings: targets)
        } catch { self.error = (error as? JobError).map(JobPresentation.message(for:)) ?? .errorFailed }
        measuring = false
    }
    func prepareAudition() async {
        guard let settings, !previewing else { return }
        previewing = true; error = nil
        defer { previewing = false }
        do {
            guard let inspector else { throw JobError.unsupported }
            let data = try await inspector.audioPreview(of: item, settings: settings)
            guard !Task.isCancelled else { return }
            audition = data; auditionSettings = settings
        } catch { self.error = (error as? JobError).map(JobPresentation.message(for:)) ?? .errorFailed }
    }

    func preset(_ value: Int) {
        targets = switch value {
        case 1: LoudnessSettings(integrated: -14, truePeak: -1, range: 11)
        case 2: LoudnessSettings(integrated: -23, truePeak: -1, range: 7)
        default: LoudnessSettings()
        }
    }
}
