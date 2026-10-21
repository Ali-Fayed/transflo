import AppKit
import Foundation
import Testing
@testable import Transflo
import TransfloDomain
import TransfloDomainTestSupport
import TransfloSystem

@Suite("Promised drops and the clipboard")
struct PromisedAndClipboardTests {
    private let point = WheelPoint(x: 500, y: 400)
    private let topWedge = WheelPoint(x: 0, y: 100)
    private let placeholder = URL(fileURLWithPath: "/tmp/transflo-promised/promised-1.jpeg")
    private let received = URL(fileURLWithPath: "/Users/me/Downloads/sunset.jpeg")

    private func makeWheel() -> (WheelCoordinator, SpyJobScheduler) {
        let scheduler = SpyJobScheduler()
        let sut = WheelCoordinator(
            resolveOptions: ResolveWheelOptionsUseCase(provider: StubWheelOptionsProvider([
                .convert: [WheelOption(.format(CatalogFixtures.png))]
            ])),
            presenter: SpyWheelPresenter(),
            viewModel: WheelViewModel(bindings: .standard, layout: StubLayoutDirection(),
                                      sizing: .fixed(innerRadius: 50, outerRadius: 150)),
            scheduler: scheduler, editor: SpyToolEditor(), preparer: SpyActionPreparer()
        )
        return (sut, scheduler)
    }

    @Test("a promised drop runs the job on the files the source app delivered")
    func promisedDrop() {
        let (sut, scheduler) = makeWheel()
        sut.handle(.began(items: [placeholder]))
        sut.handle(.wheelRequested(.convert, at: point))
        var deliver: (@MainActor ([URL]) -> Void)?
        #expect(sut.handlePromisedDrop(at: topWedge) { deliver = $0 })
        #expect(scheduler.scheduled.isEmpty)
        deliver?([received])
        #expect(scheduler.scheduled == [.init(option: WheelOption(.format(CatalogFixtures.png)),
                                              items: [received], point: point)])
    }

    @Test("nothing runs when no promised files arrive, or the drop misses a wedge")
    func promisedDropWithoutFiles() {
        let (sut, scheduler) = makeWheel()
        sut.handle(.began(items: [placeholder]))
        sut.handle(.wheelRequested(.convert, at: point))
        #expect(sut.handlePromisedDrop(at: topWedge) { $0([]) })
        #expect(scheduler.scheduled.isEmpty)
        sut.handle(.began(items: [placeholder]))
        sut.handle(.wheelRequested(.convert, at: point))
        #expect(!sut.handlePromisedDrop(at: WheelPoint(x: 0, y: 0)) { $0([received]) })
        #expect(scheduler.scheduled.isEmpty)
    }

    private struct Keyboard {
        let hints = SpyHints()
        let wheel = SpyKeyboardWheel()
        let sut: KeyboardLaunchCoordinator

        init(_ clipboard: StubClipboard) {
            sut = KeyboardLaunchCoordinator(
                hotKeys: SpyHotKeys(), selection: StubFinderSelection(result: .success([])), wheel: wheel,
                hints: hints, pointer: { WheelPoint(x: 1, y: 2) }, clipboard: clipboard
            )
        }
    }

    @Test("Convert Clipboard opens the wheel for copied files, and explains an empty or unreadable clipboard")
    func convertClipboard() {
        let copied = Keyboard(StubClipboard(.success([received])))
        copied.sut.openClipboard()
        #expect(copied.wheel.opened == [[received]] && copied.hints.shown.isEmpty)
        let empty = Keyboard(StubClipboard(.success([])))
        empty.sut.openClipboard()
        #expect(empty.hints.shown == [.hintClipboardEmpty] && empty.wheel.opened.isEmpty)
        let failing = Keyboard(StubClipboard(.failure(.destinationUnavailable)))
        failing.sut.openClipboard()
        #expect(failing.hints.shown == [JobPresentation.message(for: .destinationUnavailable)])
    }

    @Test("a copied image is saved as a PNG; copied files are returned as they are")
    func clipboardReader() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("transflo-clip-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("transflo.tests.\(UUID())"))
        defer { pasteboard.releaseGlobally() }
        let image = NSImage(size: NSSize(width: 4, height: 4), flipped: false) { rect in
            NSColor.systemTeal.setFill()
            rect.fill()
            return true
        }
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
        let date = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let reader = PasteboardClipboardReader(pasteboard: pasteboard, folder: { folder }, now: { date })
        let saved = try reader.files()
        #expect(saved.count == 1 && saved[0].pathExtension == "png")
        #expect(saved.first?.lastPathComponent.hasPrefix("Clipboard ") == true)
        #expect(FileManager.default.fileExists(atPath: saved[0].path))
        #expect(try reader.files().first?.lastPathComponent.hasSuffix(" 2.png") == true)
        pasteboard.clearContents()
        pasteboard.writeObjects([saved[0] as NSURL])
        #expect(try reader.files() == [saved[0]])
        pasteboard.clearContents()
        #expect(try reader.files().isEmpty)
    }
}

private struct StubClipboard: ClipboardFilesReading {
    let result: Result<[URL], JobError>
    init(_ result: Result<[URL], JobError>) { self.result = result }
    func files() throws(JobError) -> [URL] { try result.get() }
}
