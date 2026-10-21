import Foundation
import Testing
import TransfloData
import TransfloDomain
@testable import TransfloMobile
import UIKit

@Suite("Every advertised mobile tool/input pairing", .serialized)
struct MobileToolMatrixTests {
    struct Pair: Sendable {
        let tool: ToolKind
        let format: FormatID
        let batch: Bool
    }

    static var pairs: [Pair] {
        let conversions = MobileConversionFactory()
        let factory = MobileToolFactory(formats: conversions.catalog,
                                        suffixes: LocalizedToolSuffixes(language: .english))
        let inputs = MobileInputCatalog(catalog: conversions.catalog, tools: factory.catalog)
        return factory.catalog.tools.flatMap { tool in
            conversions.catalog.formats.compactMap { format in
                let sample = URL(fileURLWithPath: "/fixture.\(format.extensions.first ?? "")")
                let batch = [FormatDescriptor?](repeating: format, count: tool.requiresMultipleFiles ? 2 : 1)
                guard inputs.accepts([sample]), tool.accepts(format),
                      factory.engines.contains(where: { $0.canRun(tool.kind, on: batch) }) else { return nil }
                return Pair(tool: tool.kind, format: format.id, batch: tool.requiresMultipleFiles)
            }
        }
    }

    nonisolated static var isPhysicalDevice: Bool {
        #if targetEnvironment(simulator)
        false
        #else
        true
        #endif
    }

    static var nativePairs: [Pair] { pairs.filter { !hardwareTools.contains($0.tool) } }
    static var visionPairs: [Pair] { pairs.filter { hardwareTools.contains($0.tool) } }
    private static let hardwareTools: Set<ToolKind> = [.removeBackground, .describeImage]

    @Test("hardware-only Vision/model semantics; simulator cannot create the Espresso context",
          .enabled(if: isPhysicalDevice), arguments: await MainActor.run { visionPairs })
    func hardware(pair: Pair) async throws { try await run(pair: pair) }

    @Test("tool output semantics and source preservation", arguments: await MainActor.run { nativePairs })
    func run(pair: Pair) async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let fixture = try MobileMatrixFixtures.file(pair.format.rawValue,
                                                    name: pair.tool == .readCode ? "qr" : "source")
        let source = root.appendingPathComponent("first.\(fixture.pathExtension)")
        try FileManager.default.copyItem(at: fixture, to: source)
        let original = try Data(contentsOf: source)
        var inputs = [source]
        if pair.batch {
            let second = root.appendingPathComponent("second.\(fixture.pathExtension)")
            try FileManager.default.copyItem(at: source, to: second)
            inputs.append(second)
        }
        let model = MobileToolEditorModel(tool: pair.tool, items: inputs)
        await model.load()
        configure(model)
        let catalog = MobileConversionFactory().catalog
        let runner = MobileToolFactory(formats: catalog,
                                        suffixes: LocalizedToolSuffixes(language: .english)).makeRunner()
        if [.readCode, .describeImage].contains(pair.tool) { UIPasteboard.general.string = nil }
        do {
            let outputs = try await runner.run(WheelOption(.tool(pair.tool), settings: settings(model)),
                                               on: inputs, progress: { _ in })
            #expect(try Data(contentsOf: source) == original)
            try await MobileToolOutputChecks.verify(outputs, pair: pair, source: source, original: original)
            print("MOBILE_TOOL_PASS \(pair.tool.rawValue) / \(pair.format.rawValue)")
        } catch let error as JobError where pair.tool == .compress
            && [.targetUnreachable, .nothingFound].contains(error) {
            #expect(try Data(contentsOf: source) == original)
            #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).count == inputs.count)
            print("MOBILE_TOOL_SAFE_REFUSAL compress / \(pair.format.rawValue): already small")
        } catch let error as JobError where pair.tool == .removeBackground && error == .nothingFound {
            #expect(try Data(contentsOf: source) == original)
            print("MOBILE_TOOL_NEGATIVE_ONLY removeBackground / \(pair.format.rawValue): no subject")
        }
    }

    private func configure(_ model: MobileToolEditorModel) {
        model.width = 128
        model.height = 128
        model.cropWidth = 0.5
        model.cropHeight = 0.5
        model.brightness = 0.1
        model.title = "QA Title"
        model.author = "QA Author"
        model.speed = 2
        model.trimStart = 0.5
        model.trimEnd = 2.5
        model.splitEvery = 1
        model.selectedPages = [1]
        model.pages.reverse()
        model.pattern = "QA-{n}"
    }

    private func settings(_ model: MobileToolEditorModel) -> ToolSettings {
        let box = NormalizedRect(x: 0.1, y: 0.1, width: 0.5, height: 0.5)
        let annotation = Annotation(kind: .rectangle, points: [.init(x: 0.1, y: 0.1), .init(x: 0.6, y: 0.6)],
                                    color: "FF0000", weight: 0.04)
        switch model.tool {
        case .annotate: return model.isPDF ? .pageAnnotations([1: [annotation]]) : .annotate([annotation])
        case .redact: return model.isPDF ? .pageRedactions([1: [box]]) : .redact([box])
        default: return model.settings
        }
    }
}
