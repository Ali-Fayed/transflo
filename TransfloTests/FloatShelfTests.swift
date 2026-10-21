import Foundation
import Testing
@testable import Transflo

@Suite("Float shelf")
struct FloatShelfTests {
    private let photo = URL(fileURLWithPath: "/tmp/photo.heic")
    private let report = URL(fileURLWithPath: "/tmp/report.pdf")

    @Test("files keep arrival order and appear once; adding expands a collapsed shelf")
    func add() {
        let sut = FloatShelfViewModel()
        #expect(sut.isEmpty)
        sut.add([photo, report])
        sut.toggleCollapsed()
        sut.add([URL(fileURLWithPath: "/tmp/./photo.heic"), report])
        #expect(sut.items == [photo, report])
        #expect(!sut.isCollapsed)
    }

    @Test("removing and clearing empty the shelf")
    func removeAndClear() {
        let sut = FloatShelfViewModel()
        sut.add([photo, report])
        sut.remove(photo)
        #expect(sut.items == [report])
        sut.remove(photo)
        sut.toggleCollapsed()
        sut.clear()
        #expect(sut.isEmpty && !sut.isCollapsed)
    }

    @Test("the panel grows a row per file up to the limit, and collapses to a pill")
    func layout() {
        let one = ShelfLayout.size(itemCount: 1, collapsed: false)
        let three = ShelfLayout.size(itemCount: 3, collapsed: false)
        let many = ShelfLayout.size(itemCount: 50, collapsed: false)
        let limit = ShelfLayout.size(itemCount: AppDimensions.Shelf.maxVisibleRows, collapsed: false)
        #expect(three.height - one.height == AppDimensions.Shelf.rowHeight * 2)
        #expect(many == limit && one.width == many.width)
        let pill = ShelfLayout.size(itemCount: 50, collapsed: true)
        #expect(pill.width == pill.height && pill.width < one.width)
    }
}
