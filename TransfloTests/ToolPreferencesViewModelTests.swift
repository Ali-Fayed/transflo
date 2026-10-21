import Foundation
import Testing
@testable import Transflo
import TransfloDomain
import TransfloDomainTestSupport

struct ToolPreferencesViewModelTests {
    @Test func persistsPresetChoicesAndNaming() {
        let repository = InMemoryToolPreferences()
        let model = ToolPreferencesViewModel(repository: repository)
        #expect(model.choice == .medium)
        for choice: CompressionChoice in [.light, .medium, .strong] {
            model.select(choice)
            #expect(repository.loadCompressionGoal() == choice.goal)
            #expect(ToolPreferencesViewModel(repository: repository).choice == choice)
        }
        model.selectNameStyle(.word)
        #expect(ToolPreferencesViewModel(repository: repository).nameStyle == .word)
    }

    @Test(arguments: [CompressionGoal.targetBytes(250_000), .percentage(35)])
    func migratesLegacyBudgetsToBalanced(goal: CompressionGoal) {
        let repository = InMemoryToolPreferences(goal: goal)
        let model = ToolPreferencesViewModel(repository: repository)
        #expect(model.choice == .medium)
        #expect(repository.loadCompressionGoal() == .medium)
    }

    @Test func unchangedOriginalHasAnExplicitCompletionMessage() {
        let record = JobRecord(id: UUID(), option: WheelOption(.tool(.compress)), items: [],
                               origin: WheelPoint(x: 0, y: 0), state: .succeeded(outputs: []),
                               originalWithinTarget: true)
        #expect(JobPresentation.title(for: record).key == .hudWithinTarget)
        #expect(JobPresentation.message(for: .targetUnreachable) == .errorTargetUnreachable)
    }
}
