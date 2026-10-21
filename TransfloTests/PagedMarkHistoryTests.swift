import Testing
@testable import Transflo

@Suite("Paged mark history")
struct PagedMarkHistoryTests {
    @Test("commit, undo and redo walk the current page's history; a new edit clears redo")
    func undoRedo() {
        var sut = PagedMarkHistory<Int>()
        sut.commit([1])
        sut.commit([1, 2])
        sut.undo()
        #expect(sut.marks == [1] && sut.canRedo)
        sut.redo()
        #expect(sut.marks == [1, 2] && !sut.canRedo)
        sut.undo()
        sut.commit([7])
        #expect(!sut.canRedo && sut.marks == [7])
    }

    @Test("unchanged commits and out-of-range removals record nothing")
    func noOps() {
        var sut = PagedMarkHistory<Int>()
        sut.commit([])
        sut.remove(at: 0)
        #expect(!sut.canUndo)
        sut.commit([4, 5])
        sut.remove(at: 9)
        sut.remove(at: 0)
        #expect(sut.marks == [5])
        sut.undo()
        #expect(sut.marks == [4, 5])
    }

    @Test("history keeps the newest steps up to its depth")
    func depth() {
        var sut = PagedMarkHistory<Int>()
        for value in 1...(PagedMarkHistory<Int>.depth + 10) { sut.commit([value]) }
        var undone = 0
        while sut.canUndo {
            sut.undo()
            undone += 1
        }
        #expect(undone == PagedMarkHistory<Int>.depth)
        #expect(sut.marks == [10])
    }

    @Test("each page keeps its own marks and history, and empty pages are not reported")
    func pages() {
        var sut = PagedMarkHistory<String>()
        sut.commit(["a"])
        sut.select(page: 2)
        #expect(sut.marks.isEmpty && !sut.canUndo && sut.page == 2)
        sut.commit(["b"])
        sut.select(page: 5)
        #expect(sut.changesByPage == [0: ["a"], 2: ["b"]])
        sut.select(page: 0)
        #expect(sut.marks == ["a"] && sut.canUndo)
        sut.undo()
        #expect(sut.changesByPage == [2: ["b"]])
        sut.select(page: 0)
        #expect(sut.page == 0 && sut.canRedo)
    }
}
