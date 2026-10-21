import Foundation
import Testing
@testable import TransfloData
import TransfloDomain

@Suite("Subtitles")
struct SubtitleTests {
    static func format(_ id: String, family: FormatFamily, extensions: [String]? = nil) -> FormatDescriptor {
        FormatDescriptor(
            id: FormatID(id),
            displayName: id.uppercased(),
            extensions: extensions ?? [id],
            family: family
        )
    }

    @Test("SRT parses cues with multi-line text")
    func parsesSRT() {
        let cues = SubtitleParser.cues(from: DocumentFixtures.srt)
        #expect(cues == [
            SubtitleCue(start: 1000, end: 2500, text: "Hello there."),
            SubtitleCue(start: 3000, end: 4000, text: "Second line\nspans two rows.")
        ])
    }

    @Test("VTT parses headers, NOTE blocks, cue ids, settings, hour-less stamps, CRLF and BOM")
    func parsesVTT() {
        let vtt = [
            "\u{FEFF}WEBVTT - demo", "", "NOTE ignored", "", "intro", "01:02.003 --> 01:04.000 align:start", "Hi", ""
        ].joined(separator: "\r\n")
        #expect(SubtitleParser.cues(from: vtt) == [SubtitleCue(start: 62003, end: 64000, text: "Hi")])
    }

    @Test("timestamps parse in both styles and reject junk", arguments: [
        ("00:00:01,500", 1500), ("01:00:00.000", 3_600_000), ("02:03.4", 123_004)
    ])
    func stamps(stamp: String, millis: Int) {
        #expect(SubtitleParser.milliseconds(stamp) == millis)
    }

    @Test("bad timestamps are rejected")
    func badStamps() {
        #expect(SubtitleParser.milliseconds("1:2") == nil)
        #expect(SubtitleParser.milliseconds("aa:bb:cc,ddd") == nil)
        #expect(SubtitleParser.milliseconds(nil) == nil)
    }

    @Test("SRT → VTT → SRT keeps every cue")
    func roundTrip() {
        let cues = SubtitleParser.cues(from: DocumentFixtures.srt)
        let vtt = SubtitleWriter.text(for: cues, style: .vtt)
        #expect(vtt.hasPrefix("WEBVTT\n\n00:00:01.000 --> 00:00:02.500"))
        let backToSRT = SubtitleWriter.text(for: SubtitleParser.cues(from: vtt), style: .srt)
        #expect(SubtitleParser.cues(from: backToSRT) == cues)
        #expect(SubtitleWriter.text(for: cues, style: .plainText) == "Hello there.\nSecond line\nspans two rows.\n")
    }

    @Test("a file without cues fails; legacy encodings are read")
    func edgeFiles() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let srt = Self.format("srt", family: .subtitle)
        let vtt = Self.format("vtt", family: .subtitle)
        let empty = try folder.file("empty.srt", contents: "no timing here")
        let output = folder.url.appendingPathComponent("o.vtt")
        let request = ConversionRequest(source: empty, destination: output, sourceFormat: srt, targetFormat: vtt)
        await #expect(throws: JobError.failed) { _ = try await SubtitleEngine().convert(request) { _ in } }
        let latin = folder.url.appendingPathComponent("latin.srt")
        try "1\n00:00:01,000 --> 00:00:02,000\nCafé\n".data(using: .windowsCP1252)?.write(to: latin)
        #expect(try TextFileReader.read(latin).contains("Café"))
    }
}

@Suite("Archives")
struct ArchiveTests {
    private let zip = SubtitleTests.format("zip", family: .archive)
    private let gzip = SubtitleTests.format("gz", family: .archive, extensions: ["tar.gz", "gz"])
    private let tar = SubtitleTests.format("tar", family: .archive)

    @Test("entry path policy blocks escapes", arguments: [
        ("a.txt", true), ("docs/b.txt", true), ("./c", true), ("dots..ok/x", true),
        ("/etc/passwd", false), ("../evil", false), ("docs/../../evil", false), ("~/x", false)
    ])
    func pathPolicy(entry: String, safe: Bool) {
        #expect(ArchivePathPolicy.isSafe(entry) == safe)
    }

    @Test("an archive with a traversal entry is refused and writes nothing")
    func refusesZipSlip() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let staging = try FileManager.default.url(
            for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: folder.url, create: true
        )
        let inner = staging.appendingPathComponent("inner")
        try FileManager.default.createDirectory(at: inner, withIntermediateDirectories: true)
        try Data("x".utf8).write(to: staging.appendingPathComponent("evil.txt"))
        let malicious = folder.url.appendingPathComponent("slip.tar")
        let status = await ProcessRunner.run(
            executable: DocumentFixtures.bsdtar,
            arguments: ["-cf", malicious.path, "-C", inner.path, "-s", ",^,../,", "../evil.txt"],
            onStdoutLine: { _ in }, onStderrLine: { _ in }
        )
        #expect(status == 0)
        #expect(await DocumentFixtures.entries(of: malicious)?.contains { $0.hasPrefix("../") } == true)
        let output = folder.url.appendingPathComponent("slip.zip")
        let request = ConversionRequest(source: malicious, destination: output, sourceFormat: tar, targetFormat: zip)
        await #expect(throws: JobError.failed) { _ = try await ArchiveEngine().convert(request) { _ in } }
        #expect(!FileManager.default.fileExists(atPath: output.path))
    }

    @Test("a single gzipped file becomes an archive containing that file")
    func singleGzip() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let plain = try folder.file("notes.txt", contents: "hello\n")
        _ = await ProcessRunner.run(
            executable: URL(fileURLWithPath: "/usr/bin/gzip"), arguments: ["-k", plain.path],
            onStdoutLine: { _ in }, onStderrLine: { _ in }
        )
        let source = folder.url.appendingPathComponent("notes.txt.gz")
        let output = folder.url.appendingPathComponent("notes.zip")
        let request = ConversionRequest(source: source, destination: output, sourceFormat: gzip, targetFormat: zip)
        _ = try await ArchiveEngine().convert(request) { _ in }
        #expect(await DocumentFixtures.entries(of: output) == ["notes.txt"])
    }

    @Test("extracted entries with no permissions are made readable before re-packing")
    func permissions() throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let locked = try folder.file("locked.txt")
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: locked.path)
        ArchiveEngine.grantOwnerAccess(in: folder.url)
        let mode = try FileManager.default.attributesOfItem(atPath: locked.path)[.posixPermissions] as? Int
        #expect(mode == 0o600)
    }

    @Test("a corrupt archive fails cleanly")
    func corrupt() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let bad = try folder.file("bad.zip", contents: "PK not really")
        let output = folder.url.appendingPathComponent("bad.tar")
        let request = ConversionRequest(source: bad, destination: output, sourceFormat: zip, targetFormat: tar)
        await #expect(throws: JobError.failed) { _ = try await ArchiveEngine().convert(request) { _ in } }
    }

    @Test("the RAR fixture is a valid archive")
    func rarFixture() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let rar = folder.url.appendingPathComponent("f.rar")
        try RARFixture.archive(fileName: "hello.txt", contents: Data("hi\n".utf8)).write(to: rar)
        #expect(await DocumentFixtures.entries(of: rar) == ["hello.txt"])
        #expect(RARFixture.crc32(Data("123456789".utf8)) == 0xCBF4_3926)
    }
}
