import Foundation
import Observation
import TransfloDomain

/// State and intents for the open wheel: which options it shows, which page of them is visible,
/// and which wedge is under the pointer.
///
/// Up to 12 options fit on one ring, which grows with the option count (`WheelSizing`). Longer
/// lists show 11 per page plus a More wedge; resting the pointer on More for `dwellDelay` turns
/// to the next page (wrapping around).
@Observable
final class WheelViewModel {
    /// Everything the wheel renders.
    struct State: Equatable {
        var kind: WheelKind?
        var options: [WheelOption] = []
        var summary: DragSummary?
        var page = 0
        var group: WheelToolGroup?
        var slots: [WheelSlot] = []
        var highlightedIndex: Int?
        var geometry = WheelGeometry(wedgeCount: 0, innerRadius: 0, outerRadius: 0, isRightToLeft: false)
    }

    static let wedgesPerRing = 12

    private(set) var state = State()

    @ObservationIgnored private var bindings: WheelKeyBindings
    @ObservationIgnored private let layout: any LayoutDirectionProviding
    @ObservationIgnored private let sizingProvider: (() -> WheelSizing)?
    @ObservationIgnored private let byteFormatter: (any ByteSizeFormatting)?
    @ObservationIgnored private let localizer: Localizer?
    @ObservationIgnored private let sizing: WheelSizing
    @ObservationIgnored private let dwellDelay: Duration
    @ObservationIgnored private let navigationGrace: Duration
    @ObservationIgnored private var hoverReadyAt: ContinuousClock.Instant?
    @ObservationIgnored private let onSelectionChange: () -> Void
    @ObservationIgnored private var dwellTask: Task<Void, Never>?

    init(
        bindings: WheelKeyBindings,
        layout: any LayoutDirectionProviding,
        sizing: WheelSizing = .standard,
        dwellDelay: Duration = .milliseconds(400),
        navigationGrace: Duration = .seconds(1),
        sizingProvider: (() -> WheelSizing)? = nil,
        byteFormatter: (any ByteSizeFormatting)? = nil,
        localizer: Localizer? = nil,
        onSelectionChange: @escaping () -> Void = {}
    ) {
        self.onSelectionChange = onSelectionChange
        self.byteFormatter = byteFormatter
        self.localizer = localizer
        self.bindings = bindings
        self.layout = layout
        self.sizing = sizing
        self.sizingProvider = sizingProvider
        self.dwellDelay = dwellDelay
        self.navigationGrace = navigationGrace
    }

    /// The modifier glyph shown in the hub, e.g. "⇧" for Convert.
    var hubGlyph: String {
        guard let kind = state.kind, let key = bindings.key(for: kind) else { return "" }
        return WheelPresentation.glyph(for: key)
    }

    /// Useful selection facts, replaced by the hovered option inside the hub component.
    var hubDetail: String? {
        guard state.group == nil, let summary = state.summary, summary.itemCount > 0,
              let total = summary.totalBytes, let byteFormatter, let localizer else { return nil }
        let size = byteFormatter.string(bytes: total, locale: localizer.locale)
        guard summary.itemCount > 1 else { return size }
        let count = summary.itemCount.formatted(.number.locale(localizer.locale))
        return localizer.string(.wheelSelectionSummary, arguments: [count, size])
    }

    var hubTitle: L10nKey {
        state.group?.title ?? state.kind.map(WheelPresentation.title(for:)) ?? .wheelConvert
    }

    var pageCount: Int {
        let count = navigationSlots.count
        let capacity = Self.wedgesPerRing - (state.group == nil ? 0 : 1)
        guard count > capacity else { return 1 }
        let perPage = capacity - 1
        return (count + perPage - 1) / perPage
    }

    /// Shows `options` for `kind`, laid out for the current reading direction.
    func show(_ kind: WheelKind, options: [WheelOption], summary: DragSummary? = nil) {
        dwellTask?.cancel()
        hoverReadyAt = nil
        var seen: Set<String> = []
        state = State(kind: kind, options: options.filter { seen.insert($0.id).inserted }, summary: summary)
        layOut(page: 0)
    }

    /// Highlights the wedge under `offset` (from the wheel center, y up); `nil` clears it.
    /// Resting on More starts the page-turn timer.
    /// - Returns: Whether the pointer is over a droppable option.
    @discardableResult
    func updatePointer(_ offset: WheelPoint?) -> Bool {
        let index = offset.flatMap(state.geometry.wedgeIndex(at:))
        if index != state.highlightedIndex {
            state.highlightedIndex = index
            if let index, state.slots[index] != .more { onSelectionChange() }
            dwellTask?.cancel()
            if let index, isNavigation(state.slots[index]) { startDwell() }
        }
        guard let index else { return false }
        return state.slots[index] != .more
    }

    private func isNavigation(_ slot: WheelSlot) -> Bool {
        switch slot {
        case .group, .back, .more: true
        case .option: false
        }
    }

    /// Opens a group, returns to the root, or turns a page without dispatching a file operation.
    @discardableResult
    func navigate(at offset: WheelPoint) -> Bool {
        guard let index = state.geometry.wedgeIndex(at: offset) else { return false }
        return navigate(state.slots[index])
    }

    @discardableResult
    private func navigate(_ slot: WheelSlot) -> Bool {
        switch slot {
        case .group(let group): openGroup(group)
        case .back:
            dwellTask?.cancel()
            hoverReadyAt = ContinuousClock.now.advanced(by: navigationGrace)
            state.group = nil
            layOut(page: 0)
        case .more: turnPage()
        case .option: return false
        }
        return true
    }

    func openGroup(_ group: WheelToolGroup) {
        guard state.kind == .tools, state.options.contains(where: { WheelToolGroup.group(for: $0) == group }) else {
            return
        }
        dwellTask?.cancel()
        state.group = group
        layOut(page: 0)
    }

    /// Whether the pointer is on the paging control.
    func isMore(at offset: WheelPoint) -> Bool {
        guard let index = state.geometry.wedgeIndex(at: offset) else { return false }
        return state.slots[index] == .more
    }

    /// The option under `offset`, or `nil` over the hub, More, or outside the ring.
    func option(at offset: WheelPoint) -> WheelOption? {
        guard let index = state.geometry.wedgeIndex(at: offset), case .option(let option) = state.slots[index] else {
            return nil
        }
        return option
    }

    /// Uses new key bindings from now on (the hub glyph and modifier taps in keyboard mode).
    func update(bindings: WheelKeyBindings) {
        self.bindings = bindings
    }

    /// Keyboard mode: highlights the wedge under the pointer. Over the hub or outside the ring
    /// the arrow-key highlight stays, and More never auto-turns.
    func highlightWedge(at offset: WheelPoint) {
        guard let index = state.geometry.wedgeIndex(at: offset) else { return }
        dwellTask?.cancel()
        if index != state.highlightedIndex {
            state.highlightedIndex = index
            if case .option = state.slots[index] { onSelectionChange() }
        }
    }

    /// The wheel bound to `key`, if any.
    func wheel(for key: ModifierKey) -> WheelKind? {
        bindings.wheel(for: key)
    }

    /// Moves the highlight one wedge as seen on screen (right-to-left wheels run counter-clockwise),
    /// wrapping around. Keyboard highlighting never auto-turns pages.
    func stepHighlight(clockwise: Bool) {
        guard !state.slots.isEmpty else { return }
        let count = state.slots.count
        dwellTask?.cancel()
        let step = clockwise == state.geometry.isRightToLeft ? -1 : 1
        guard let current = state.highlightedIndex else {
            // The first press lands on the top wedge going clockwise, or on its neighbor going back.
            state.highlightedIndex = clockwise ? 0 : (step + count) % count
            selectionFeedback()
            return
        }
        state.highlightedIndex = (current + step + count) % count
        if state.highlightedIndex != current { selectionFeedback() }
    }

    private func selectionFeedback() {
        guard let index = state.highlightedIndex, state.slots[index] != .more else { return }
        onSelectionChange()
    }

    /// The highlighted option, or `nil` when nothing is highlighted. On More this turns the page
    /// and keeps More highlighted, so pressing again keeps paging.
    func activateHighlighted() -> WheelOption? {
        guard let index = state.highlightedIndex, state.slots.indices.contains(index) else { return nil }
        guard case .option(let option) = state.slots[index] else {
            let wasMore = state.slots[index] == .more
            navigate(state.slots[index])
            if wasMore { state.highlightedIndex = state.slots.firstIndex(of: .more) }
            return nil
        }
        return option
    }

    /// Shows the next page of options (wrapping).
    func turnPage() {
        dwellTask?.cancel()
        guard pageCount > 1 else { return }
        layOut(page: (state.page + 1) % pageCount)
    }

    /// Clears the wheel after it closes.
    func reset() {
        dwellTask?.cancel()
        state = State()
    }

    private func startDwell() {
        let isBack = state.highlightedIndex.map { state.slots[$0] == .back } ?? false
        let remainingGrace = hoverReadyAt.map { ContinuousClock.now.duration(to: $0) } ?? .zero
        let delay = max(isBack ? navigationGrace : dwellDelay, remainingGrace)
        dwellTask = Task { [weak self, delay] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            guard let self, let index = state.highlightedIndex, state.slots.indices.contains(index) else { return }
            navigate(state.slots[index])
        }
    }

    private func layOut(page: Int) {
        let options = navigationSlots
        let capacity = Self.wedgesPerRing - (state.group == nil ? 0 : 1)
        let slots: [WheelSlot]
        if options.count <= capacity {
            slots = options
        } else {
            let perPage = capacity - 1
            slots = Array(options.dropFirst(page * perPage).prefix(perPage)) + [.more]
        }
        state.page = page
        state.slots = slots + (state.group == nil ? [] : [.back])
        state.highlightedIndex = nil
        let sizing = sizingProvider?() ?? sizing
        state.geometry = WheelGeometry(
            wedgeCount: state.slots.count,
            innerRadius: sizing.innerRadius,
            outerRadius: sizing.outerRadius(forWedgeCount: state.slots.count),
            isRightToLeft: layout.isRightToLeft
        )
    }

    private var navigationSlots: [WheelSlot] {
        if let group = state.group {
            return state.options.filter { WheelToolGroup.group(for: $0) == group }.map(WheelSlot.option)
        }
        return state.kind == .tools ? WheelToolGroup.rootSlots(for: state.options) : state.options.map(WheelSlot.option)
    }
}
