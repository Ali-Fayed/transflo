import Foundation
import Testing
@testable import TransfloData
import TransfloDomain

/// Opt-in local verification. User documents and generated outputs never enter the repository.
@Suite("Release verification with external fixtures", .serialized,
       .enabled(if: ProcessInfo.processInfo.environment["TRANSFLO_VERIFICATION_ROOT"] != nil))
struct ReleaseVerificationTests {
    @Test("exercise every catalog conversion and every available tool/format pair")
    func verifyRelease() async throws {
        let path = try #require(ProcessInfo.processInfo.environment["TRANSFLO_VERIFICATION_ROOT"])
        let root = URL(fileURLWithPath: path, isDirectory: true)
        let fixtures = VerificationFixtures(root: root)
        var report = VerificationReport(root: root)
        try await fixtures.prepare(report: &report)
        let catalog = MatrixConversionTests.catalog
        let paths = catalog.paths.sorted { "\($0.source)→\($0.target)" < "\($1.source)→\($1.target)" }
        let phase = ProcessInfo.processInfo.environment["TRANSFLO_VERIFICATION_PHASE"]
        let toolsOnly = phase == "tools" || phase == "failed"
        for path in paths where !toolsOnly {
            let id = "convert-\(path.source)-\(path.target)"
            let source = fixtures.file(path.source.rawValue)
            await conversion(id, source: source, target: path.target.rawValue, report: &report)
        }
        let originals = try FileManager.default.contentsOfDirectory(
            at: root.deletingLastPathComponent(), includingPropertiesForKeys: [.isRegularFileKey]
        ).filter { ["pdf", "png"].contains($0.pathExtension.lowercased()) }
        for source in originals where !toolsOnly {
            guard let format = catalog.format(forFileExtension: source.pathExtension) else { continue }
            for path in paths where path.source == format.id {
                let id = "real-\(format.id)-\(path.target)"
                await conversion(id, source: source, target: path.target.rawValue, report: &report)
            }
        }
        try await VerificationTools(root: root, fixtures: fixtures).run(report: &report)
        try report.save(finished: true)
        let failures = report.rows.filter { $0.status == "FAIL" }
        #expect(failures.isEmpty, "See external verification report: \(failures.map(\.id).joined(separator: ", "))")
    }

    @Test("AVI speed and Ogg metadata receive focused release regressions")
    func focusedRegressions() async throws {
        let path = try #require(ProcessInfo.processInfo.environment["TRANSFLO_VERIFICATION_ROOT"])
        let root = URL(fileURLWithPath: path, isDirectory: true)
        var report = VerificationReport(root: root)
        try await VerificationDiagnostics.run(root: root, report: &report)
        try report.save(finished: true)
        #expect(!report.rows.contains { $0.id.hasPrefix("edge-") && $0.status == "FAIL" })
    }

    private func conversion(
        _ id: String, source: URL, target: String, report: inout VerificationReport
    ) async {
        let started = Date()
        do {
            let directory = try report.directory(id)
            let input = directory.appendingPathComponent(source.lastPathComponent)
            try FileManager.default.copyItem(at: source, to: input)
            let format = try #require(MatrixConversionTests.catalog.format(FormatID(target)))
            let outputs = try await VerificationSupport.timed {
                try await MatrixConversionTests.makeRunner().run(WheelOption(.format(format)), on: [input]) { _ in }
            }
            try await VerificationSupport.validate(outputs, target: target)
            try VerificationSupport.unchanged(source, copy: input)
            report.append(id, status: "PASS", detail: "Readable \(target) output; original preserved",
                          outputs: outputs, started: started)
        } catch {
            report.append(id, error: error, started: started)
        }
    }
}
