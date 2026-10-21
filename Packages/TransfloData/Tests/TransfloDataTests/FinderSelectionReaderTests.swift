import Foundation
import Testing
@testable import TransfloData
import TransfloDomain

@Suite("Finder selection")
struct FinderSelectionReaderTests {
    @Test("paths become file URLs; folders keep their trailing slash; noise is dropped")
    func parsing() {
        let urls = FinderSelectionReader.urls(from: ["/Users/example/a b.png", "/Users/example/Album/", "", "oops"])
        #expect(urls.map(\.path) == ["/Users/example/a b.png", "/Users/example/Album"])
        #expect(urls.map(\.hasDirectoryPath) == [false, true])
    }

    @Test("the script reads the selection and passes no file paths inside its source")
    func script() {
        #expect(FinderSelectionReader.script.contains { $0.contains("selection as alias list") })
        #expect(!FinderSelectionReader.script.joined().contains("/Users"))
    }

    @Test("a refused Automation request reads as automation denied")
    func denied() {
        #expect(IWorkAutomation.error(from: ["execution error: Not authorized to send Apple events (-1743)"])
            == .automationDenied)
    }
}
