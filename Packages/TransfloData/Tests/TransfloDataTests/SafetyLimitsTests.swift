import CoreGraphics
import Foundation
import Testing
@testable import TransfloData
import TransfloDomain

@Suite("XML text")
struct XMLTextTests {
    @Test("markup characters are escaped, ampersands first")
    func escapes() {
        #expect(XMLText.escape(#"<a href="x">Tom & Jerry</a>"#)
            == "&lt;a href=&quot;x&quot;&gt;Tom &amp; Jerry&lt;/a&gt;")
        #expect(XMLText.escape("&amp;") == "&amp;amp;")
    }

    @Test("control characters XML forbids are dropped; tabs and newlines stay")
    func controlCharacters() {
        #expect(XMLText.escape("a\u{0}b\u{1B}c\u{7}") == "abc")
        #expect(XMLText.escape("line\tone\nline\rtwo") == "line\tone\nline\rtwo")
        #expect(XMLText.escape("مرحبا 👋") == "مرحبا 👋")
    }
}

@Suite("Raster limits")
struct RasterLimitsTests {
    @Test("ordinary and large-but-bounded images are allowed")
    func allows() {
        #expect(RasterLimits.allows(CGSize(width: 1, height: 1)))
        #expect(RasterLimits.allows(CGSize(width: 8000, height: 8000)))
        #expect(RasterLimits.allows(CGSize(width: 32_768, height: 1953)))
    }

    @Test("empty, non-finite, over-wide and over-area images are refused",
          arguments: [
              CGSize(width: 0, height: 10), CGSize(width: 10, height: 0.5),
              CGSize(width: CGFloat.nan, height: 10), CGSize(width: 10, height: CGFloat.infinity),
              CGSize(width: 32_769, height: 1), CGSize(width: 9000, height: 9000)
          ])
    func refuses(size: CGSize) {
        #expect(!RasterLimits.allows(size))
    }

    @Test("work inside the pool keeps its value and its typed error")
    func pool() {
        #expect((try? RasterLimits.withPool { () throws(JobError) in 42 }) == 42)
        #expect(throws: JobError.unsupported) {
            try RasterLimits.withPool { () throws(JobError) -> Int in throw .unsupported }
        }
    }
}

@Suite("Extraction budget")
struct ExtractionBudgetTests {
    private func makeFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("transflo-budget-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    @Test("a normal extracted document is within budget")
    func permits() throws {
        let folder = try makeFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        try Data(repeating: 1, count: 4096).write(to: folder.appendingPathComponent("document.xml"))
        #expect(ExtractionBudget.permits(folder))
    }

    @Test("an archive that expands past the byte budget is refused")
    func refusesHugeExpansion() throws {
        let folder = try makeFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let bomb = folder.appendingPathComponent("bomb.bin")
        FileManager.default.createFile(atPath: bomb.path, contents: nil)
        // A sparse file reports its full length without using the disk space.
        let handle = try FileHandle(forWritingTo: bomb)
        try handle.truncate(atOffset: UInt64(ExtractionBudget.maximumBytes) + 1)
        try handle.close()
        #expect(!ExtractionBudget.permits(folder))
    }

    @Test("a missing folder is refused")
    func missingFolder() {
        #expect(!ExtractionBudget.permits(URL(fileURLWithPath: "/nonexistent/transflo-\(UUID().uuidString)")))
    }
}

@Suite("Loudness processor")
struct LoudnessProcessorTests {
    private let measured = LoudnessMeasurement(integrated: -23.5, truePeak: -4.1, range: 7.2, threshold: -34,
                                               offset: 0.3)

    @Test("the second pass feeds back every measured value, linearly")
    func secondPass() throws {
        let arguments = try #require(LoudnessProcessor.arguments(LoudnessSettings(), measured: measured,
                                                                 format: "mp3"))
        let filter = try #require(arguments.firstIndex(of: "-af").map { arguments[$0 + 1] })
        #expect(filter.hasPrefix("loudnorm=I=-16.0:TP=-1.5:LRA=11.0"))
        for part in ["measured_I=-23.5", "measured_TP=-4.1", "measured_LRA=7.2", "measured_thresh=-34.0",
                     "offset=0.3", "linear=true"] {
            #expect(filter.contains(part))
        }
        #expect(arguments.starts(with: ["-vn"]) && arguments.contains("48000"))
    }

    @Test("video keeps its picture untouched")
    func video() throws {
        let arguments = try #require(LoudnessProcessor.arguments(LoudnessSettings(), measured: measured,
                                                                 format: "mp4"))
        #expect(arguments.starts(with: ["-c:v", "copy"]) && arguments.contains("aac"))
    }

    @Test("invalid targets, silent measurements and unknown formats give no arguments")
    func refuses() {
        #expect(LoudnessProcessor.arguments(LoudnessSettings(integrated: 0), measured: measured, format: "mp3") == nil)
        let silent = LoudnessMeasurement(integrated: -.infinity, truePeak: 0, range: 0, threshold: 0, offset: 0)
        #expect(LoudnessProcessor.arguments(LoudnessSettings(), measured: silent, format: "mp3") == nil)
        #expect(LoudnessProcessor.arguments(LoudnessSettings(), measured: measured, format: "docx") == nil)
    }
}
