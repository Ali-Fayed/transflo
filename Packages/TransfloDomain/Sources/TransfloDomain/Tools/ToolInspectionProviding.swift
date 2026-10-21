import Foundation

public struct BackgroundRemovalSettings: Sendable, Hashable {
    /// Nil selects every detected subject. Instance IDs come from the source's Vision analysis.
    public var subject: Int?
    /// Feather radius as a fraction of the shorter source dimension.
    public var feather: Double
    public var background: String?
    public init(subject: Int? = nil, feather: Double = 0, background: String? = nil) {
        self.subject = subject
        self.feather = feather
        self.background = background
    }
    public var isValid: Bool {
        feather.isFinite && (0...0.02).contains(feather) && (subject.map { $0 > 0 } ?? true)
            && (background.map {
                InterfaceCustomization.validatedHex($0.replacingOccurrences(of: "#", with: "")) != nil
            }
                ?? true)
    }
}

public struct BackgroundRemovalPreview: Sendable {
    public let thumbnail: Data
    public let subjects: [Int]
    public init(thumbnail: Data, subjects: [Int]) { self.thumbnail = thumbnail; self.subjects = subjects }
}

public enum MetadataCategory: String, Sendable, Hashable, CaseIterable {
    case descriptive, location, camera, other
}

public struct MetadataEntry: Sendable, Hashable {
    public let name: String
    public let value: String
    public let category: MetadataCategory
    public init(name: String, value: String, category: MetadataCategory) {
        self.name = name; self.value = value; self.category = category
    }
}

/// Expensive inspection runs outside the UI actor, using the same algorithms as export.
public protocol ToolInspectionProviding: Sendable {
    func collage(items: [URL], settings: CollageSettings) async throws(JobError) -> Data
    func codes(in items: [URL]) async throws(JobError) -> [String]
    func background(of item: URL, settings: BackgroundRemovalSettings) async throws(JobError)
        -> BackgroundRemovalPreview
    func loudness(of item: URL, settings: LoudnessSettings) async throws(JobError) -> LoudnessMeasurement
    func metadata(in item: URL) async throws(JobError) -> [MetadataEntry]
    func audioPreview(of item: URL, settings: ToolSettings) async throws(JobError) -> Data
    func validate(_ settings: ToolSettings, tool: ToolKind, items: [URL]) async throws(JobError)
}
