import Observation
import TransfloDomain

/// Persists preset compression defaults and output naming.
@Observable
final class ToolPreferencesViewModel {
    private(set) var choice: CompressionChoice
    private(set) var nameStyle: ToolNameStyle
    @ObservationIgnored private let repository: any ToolPreferencesRepository

    init(repository: any ToolPreferencesRepository) {
        self.repository = repository
        let goal = repository.loadCompressionGoal()
        choice = CompressionChoice(goal)
        nameStyle = repository.loadNameStyle()
        // Previously saved byte/percentage budgets must not remain hidden active defaults.
        if goal != choice.goal { repository.saveCompressionGoal(choice.goal) }
    }

    func select(_ choice: CompressionChoice) {
        self.choice = choice
        repository.saveCompressionGoal(choice.goal)
    }

    func selectNameStyle(_ style: ToolNameStyle) {
        nameStyle = style
        repository.saveNameStyle(style)
    }
}
