import Foundation
import Testing
import TransfloDomain
import TransfloDomainTestSupport

@Suite("Smart Rename suggestions")
struct SmartRenameSuggestionTests {
    private let items = ["IMG_0001.jpg", "IMG_0002.jpg", "IMG_0003.heic"].map { URL(fileURLWithPath: "/tmp/\($0)") }

    private func useCase(_ understanding: StubImageUnderstanding = StubImageUnderstanding(labels: ["dog"]),
                         _ writer: StubTextWriter = StubTextWriter()) -> SuggestFileNamesUseCase {
        SuggestFileNamesUseCase(understanding: understanding, writer: writer, created: { _ in nil })
    }

    @Test func suggestsSanitizedNamesInOrder() async throws {
        let writer = StubTextWriter(names: ["Golden Retriever, on the Beach!", "Receipt: Coffee", "Red car"])
        let names = try await useCase(StubImageUnderstanding(labels: ["dog"]), writer).execute(for: items)
        #expect(names == ["golden-retriever-on-the-beach", "receipt-coffee", "red-car"])
    }

    @Test func repeatedSuggestionsAreNumbered() async throws {
        let names = try await useCase(StubImageUnderstanding(labels: ["dog"]), StubTextWriter(names: ["Dog"]))
            .execute(for: items)
        #expect(names == ["dog", "dog-2", "dog-3"])
    }

    @Test func fileWithNothingRecognizedKeepsItsName() async throws {
        let names = try await useCase(StubImageUnderstanding()).execute(for: Array(items.prefix(1)))
        #expect(names == ["IMG_0001"])
    }

    @Test func fallbackNamesStayUnchangedAcrossFolders() async throws {
        let urls = ["/a/IMG_1.png", "/b/IMG_1.png"].map { URL(fileURLWithPath: $0) }
        let names = try await useCase(StubImageUnderstanding()).execute(for: urls)
        #expect(names == ["IMG_1", "IMG_1"])
        let suggestions = try await useCase().execute(for: urls)
        #expect(suggestions == ["dog-on-beach", "dog-on-beach"])
    }

    @Test func unusableSuggestionKeepsTheCurrentName() async throws {
        let names = try await useCase(StubImageUnderstanding(labels: ["dog"]), StubTextWriter(names: ["!!!"]))
            .execute(for: Array(items.prefix(1)))
        #expect(names == ["IMG_0001"])
    }

    @Test func unavailableModelIsUnsupported() async {
        await #expect(throws: JobError.unsupported) {
            try await useCase(StubImageUnderstanding(labels: ["dog"]), StubTextWriter(isAvailable: false))
                .execute(for: items)
        }
    }

    @Test func analysisFailureIsReported() async {
        await #expect(throws: JobError.sourceMissing) {
            try await useCase(StubImageUnderstanding(error: .sourceMissing)).execute(for: items)
        }
    }

    @Test func writerFailureIsReported() async {
        await #expect(throws: JobError.failed) {
            try await useCase(StubImageUnderstanding(labels: ["dog"]), StubTextWriter(error: .failed))
                .execute(for: items)
        }
    }

    @Test func sanitizerKeepsLettersOfAnyScriptAndCapsLength() {
        #expect(FileNameSanitizer.sanitize("  ../Secret\\Plans  ") == "secret-plans")
        #expect(FileNameSanitizer.sanitize("فاتورة مقهى") == "فاتورة-مقهى")
        #expect(FileNameSanitizer.sanitize("...") == "")
        let long = FileNameSanitizer.sanitize(String(repeating: "word ", count: 40))
        #expect(long.count <= FileNameSanitizer.maximumLength && long.hasSuffix("word"))
    }
}
