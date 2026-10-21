import Foundation
import Testing
import TransfloDomain
import TransfloDomainTestSupport

@Suite("NameOutputFileUseCase")
struct NameOutputFileUseCaseTests {
    private let folder = URL(fileURLWithPath: "/Users/me/Desktop", isDirectory: true)

    private func url(_ name: String) -> URL {
        folder.appendingPathComponent(name)
    }

    private func sut(existing: [String]) -> NameOutputFileUseCase {
        NameOutputFileUseCase(checker: FakeFileExistenceChecker(existing: existing.map(url)))
    }

    @Test("a new extension uses the plain base name when free")
    func newExtension() throws {
        let result = try sut(existing: ["photo.heic"]).execute(for: url("photo.heic"), pathExtension: "png")
        #expect(result == url("photo.png"))
    }

    @Test("collisions get the next free number")
    func collisions() throws {
        let sut = sut(existing: ["photo.png", "photo 2.png"])
        let result = try sut.execute(for: url("photo.heic"), pathExtension: "png")
        #expect(result == url("photo 3.png"))
    }

    @Test("keeping the extension never overwrites the source")
    func sameExtension() throws {
        let result = try sut(existing: ["report.pdf"]).execute(for: url("report.pdf"), pathExtension: nil)
        #expect(result == url("report 2.pdf"))
    }

    @Test("files without an extension stay without one")
    func noExtension() throws {
        #expect(try sut(existing: ["Makefile"]).execute(for: url("Makefile"), pathExtension: nil) == url("Makefile 2"))
    }

    @Test("names with several dots only replace the last extension")
    func multipleDots() throws {
        let result = try sut(existing: []).execute(for: url("report.final.pdf"), pathExtension: "docx")
        #expect(result == url("report.final.docx"))
    }

    @Test("compressed tarballs drop the inner .tar", arguments: [
        ("photos.tar.gz", "zip", "photos.zip"), ("photos.TAR.GZ", "tar", "photos.tar"),
        ("logs.gz", "tar.gz", "logs.tar.gz"), ("a.tar", "zip", "a.zip"), ("notes.tar.txt", "md", "notes.tar.md")
    ])
    func tarballs(source: String, fileExtension: String, expected: String) throws {
        #expect(try sut(existing: []).execute(for: url(source), pathExtension: fileExtension) == url(expected))
    }

    @Test("dotfiles keep their full name")
    func dotfile() throws {
        #expect(try sut(existing: [".env"]).execute(for: url(".env"), pathExtension: nil) == url(".env 2"))
    }

    @Test("exhausting every candidate reports the destination as unavailable")
    func exhausted() {
        let all = ["a.txt"] + (2...NameOutputFileUseCase.maximumAttempts).map { "a \($0).txt" }
        #expect(throws: JobError.destinationUnavailable) {
            try sut(existing: all).execute(for: url("a.txt"), pathExtension: nil)
        }
    }
}
