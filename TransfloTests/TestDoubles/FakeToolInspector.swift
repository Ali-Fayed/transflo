import Foundation
import TransfloDomain

nonisolated struct FakeToolInspector: ToolInspectionProviding {
    func codes(in items: [URL]) async throws(JobError) -> [String] { ["https://example.com/", "plain text"] }
    func background(of item: URL, settings: BackgroundRemovalSettings) async throws(JobError)
        -> BackgroundRemovalPreview {
        BackgroundRemovalPreview(thumbnail: Data([1, 2, 3]), subjects: [1, 2])
    }
    func loudness(of item: URL, settings: LoudnessSettings) async throws(JobError) -> LoudnessMeasurement {
        LoudnessMeasurement(integrated: -22, truePeak: -4, range: 3, threshold: -32, offset: 0)
    }
    func metadata(in item: URL) async throws(JobError) -> [MetadataEntry] {
        [MetadataEntry(name: "Title", value: "Original", category: .descriptive),
         MetadataEntry(name: "GPS", value: "Protected", category: .location)]
    }
    func validate(_ settings: ToolSettings, tool: ToolKind, items: [URL]) async throws(JobError) {}
    func audioPreview(of item: URL, settings: ToolSettings) async throws(JobError) -> Data { Data([1]) }
    func collage(items: [URL], settings: CollageSettings) async throws(JobError) -> Data { Data([2]) }
}
