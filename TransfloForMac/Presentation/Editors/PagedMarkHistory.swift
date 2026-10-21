/// Memento for the markup editors: the marks on each page, each page with its own undo and redo.
/// Switching pages keeps every page's marks and history; only the current page is edited.
nonisolated struct PagedMarkHistory<Mark: Equatable> {
    /// Undo steps kept per page.
    static var depth: Int { 50 }

    private struct Page {
        var marks: [Mark] = []
        var undo: [[Mark]] = []
        var redo: [[Mark]] = []
    }

    private var current = Page()
    private var others: [Int: Page] = [:]
    private(set) var page = 0

    var marks: [Mark] { current.marks }
    var canUndo: Bool { !current.undo.isEmpty }
    var canRedo: Bool { !current.redo.isEmpty }

    /// Every page with at least one mark, the current page included.
    var changesByPage: [Int: [Mark]] {
        var changes = others.mapValues(\.marks)
        changes[page] = current.marks
        return changes.filter { !$0.value.isEmpty }
    }

    /// Replaces the current page's marks as one undoable step; an unchanged list records nothing.
    mutating func commit(_ next: [Mark]) {
        guard next != current.marks else { return }
        if current.undo.count == Self.depth { current.undo.removeFirst() }
        current.undo.append(current.marks)
        current.redo.removeAll()
        current.marks = next
    }

    mutating func undo() {
        guard let previous = current.undo.popLast() else { return }
        current.redo.append(current.marks)
        current.marks = previous
    }

    mutating func redo() {
        guard let next = current.redo.popLast() else { return }
        current.undo.append(current.marks)
        current.marks = next
    }

    mutating func remove(at index: Int) {
        guard current.marks.indices.contains(index) else { return }
        var next = current.marks
        next.remove(at: index)
        commit(next)
    }

    mutating func select(page index: Int) {
        guard index != page else { return }
        others[page] = current
        current = others.removeValue(forKey: index) ?? Page()
        page = index
    }
}
