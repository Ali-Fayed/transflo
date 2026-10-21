import Foundation
import Testing
import TransfloDomain
@testable import TransfloMobile

@Suite("Mobile media editors")
struct MobileMediaEditorTests {
    private func model(_ tool: ToolKind, file: String = "clip.mp4", duration: Double = 90) -> MobileToolEditorModel {
        let sut = MobileToolEditorModel(tool: tool, items: [URL(fileURLWithPath: "/tmp/\(file)")])
        sut.duration = duration
        sut.trimEnd = duration
        sut.loaded = true
        return sut
    }

    @Test("Trim sends the chosen range and refuses one shorter than a tenth of a second")
    func trim() {
        let sut = model(.trim)
        sut.trimStart = 10
        sut.trimEnd = 25
        #expect(sut.isValid && sut.settings == .trim(start: 10, end: 25))
        sut.trimEnd = 10.05
        #expect(!sut.isValid)
    }

    @Test("Change Speed needs a speed other than normal, within a quarter to four times")
    func speed() {
        let sut = model(.changeSpeed)
        sut.speed = 2
        #expect(sut.isValid && sut.settings == .changeSpeed(2))
        sut.speed = 1
        #expect(!sut.isValid)
        sut.speed = 8
        #expect(!sut.isValid)
    }

    @Test("Split cuts a recording every N seconds, and needs at least one cut")
    func split() {
        let sut = model(.split, file: "talk.m4a")
        sut.splitEvery = 30
        #expect(sut.isMedia && !sut.isPageTool)
        #expect(sut.settings == .split(points: [30, 60]))
        sut.splitEvery = 120
        #expect(!sut.isValid)
    }

    @Test("Snapshot needs a readable length and sends the chosen time")
    func snapshot() {
        let sut = model(.snapshot)
        sut.snapshotTime = 12
        #expect(sut.isValid && sut.settings == .snapshot(at: 12))
        #expect(!model(.snapshot, duration: 0).isValid)
    }

    @Test("PDF Split still means pages")
    func pdfSplit() {
        let sut = MobileToolEditorModel(tool: .split, items: [URL(fileURLWithPath: "/tmp/report.pdf")])
        #expect(sut.isPageTool && !sut.isMedia)
    }
}
