import Observation
import TransfloDomain

/// Settings › Wheel: which wedges each wheel shows. Every change is saved through the Repository
/// boundary and applies the next time a wheel opens.
@Observable
final class WheelVisibilityViewModel {
    struct Row: Identifiable, Equatable {
        let option: WheelOption
        let label: AppTextContent
        let symbol: AppSymbol?
        var id: String { option.id }
    }

    struct Group: Identifiable, Equatable {
        /// The format family for Convert; `nil` for the single group of Tools or Actions.
        let title: L10nKey?
        let rows: [Row]
        var id: String { title?.rawValue ?? "all" }
    }

    private(set) var wheel = WheelKind.convert
    private(set) var visibility: WheelVisibility
    private(set) var usage: WheelUsage
    @ObservationIgnored private let groupsByWheel: [WheelKind: [Group]]
    @ObservationIgnored private let repository: any WheelVisibilityRepository
    @ObservationIgnored private let usageRepository: (any WheelUsageRepository)?

    init(
        choices: ListWheelChoicesUseCase,
        repository: any WheelVisibilityRepository,
        usage: (any WheelUsageRepository)? = nil
    ) {
        self.repository = repository
        usageRepository = usage
        visibility = repository.loadWheelVisibility()
        self.usage = usage?.loadWheelUsage() ?? .standard
        groupsByWheel = Dictionary(uniqueKeysWithValues: WheelKind.allCases.map { kind in
            (kind, choices.execute(wheel: kind).map(WheelChoicePresentation.group(for:)))
        })
    }

    /// Wheels that have anything to show here; iPhone and iPad have no file actions, for example.
    var availableWheels: [WheelKind] {
        WheelKind.allCases.filter { groupsByWheel[$0]?.contains { !$0.rows.isEmpty } == true }
    }

    /// The selected wheel's checklist.
    var groups: [Group] { groupsByWheel[wheel] ?? [] }
    var shownCount: Int { options.filter(visibility.isVisible).count }
    var totalCount: Int { options.count }
    /// Everything is unticked, so the wheel has nothing to open with.
    var isWheelEmpty: Bool { totalCount > 0 && shownCount == 0 }

    func select(_ wheel: WheelKind) {
        self.wheel = wheel
    }

    func isVisible(_ row: Row) -> Bool {
        visibility.isVisible(row.option)
    }

    func setVisible(_ row: Row, _ visible: Bool) {
        visibility.set(row.option, visible: visible)
        save()
    }

    /// Ticks every option of the selected wheel.
    func showAll() {
        visibility.set(options, visible: true)
        save()
    }

    /// Unticks every option of the selected wheel.
    func hideAll() {
        visibility.set(options, visible: false)
        save()
    }

    private var options: [WheelOption] { groups.flatMap(\.rows).map(\.option) }

    private func save() {
        repository.saveWheelVisibility(visibility)
    }

    /// Whether pins and ordering are offered (they need somewhere to be saved).
    var supportsOrdering: Bool { usageRepository != nil }

    func isPinned(_ row: Row) -> Bool { usage.isPinned(row.option) }

    func setPinned(_ row: Row, _ pinned: Bool) {
        usage.setPinned(row.option, pinned)
        saveUsage()
    }

    func setLastUsedFirst(_ enabled: Bool) {
        usage.lastUsedFirst = enabled
        saveUsage()
    }

    func setOrdersByFrequency(_ enabled: Bool) {
        usage.ordersByFrequency = enabled
        saveUsage()
    }

    private func saveUsage() {
        usageRepository?.saveWheelUsage(usage)
    }
}
