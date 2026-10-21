import Foundation
import Testing
import TransfloData
import TransfloDomain
@testable import TransfloMobile

@Suite("Mobile output, visibility and recipes")
struct MobilePreferenceFlowTests {
    @Test("a five-minute source trimmed to two minutes has a zero-based two-minute scrubber")
    func timeline() {
        let timeline = MobileMediaTimeline(duration: 300, start: 60, end: 180)
        #expect(timeline.duration == 120)
        #expect(timeline.elapsed(at: 60) == 0 && timeline.elapsed(at: 100) == 40)
        #expect(timeline.elapsed(at: 300) == 120 && timeline.elapsed(at: 0) == 0)
        #expect(timeline.sourceTime(at: 0) == 60 && timeline.sourceTime(at: 120) == 180)
        #expect(timeline.sourceTime(at: 500) == 180)
        let faster = MobileMediaTimeline(duration: 300, start: 60, end: 180, rate: 2)
        #expect(faster.duration == 60 && faster.elapsed(at: 100) == 20)
        #expect(TimeLabel.text(80) == "1:20")
    }

    @Test("saved output settings initialize every newly opened compress editor")
    func compressionDefault() throws {
        let suite = "TransfloPreferenceTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let repository = UserDefaultsSettingsRepository(defaults: defaults)
        let output = ToolPreferencesViewModel(repository: repository)
        let choices = MobileWheelChoices(markupEditors: StubMarkupEditors(),
                                         compressionGoal: { repository.loadCompressionGoal() })
        let url = URL(fileURLWithPath: "/tmp/video.mp4")
        output.select(.strong)
        choices.edit(.compress, items: [url]) { _ in }
        #expect(choices.session?.model.compression == 2)
        choices.cancel()
        output.select(.light)
        choices.edit(.compress, items: [url]) { _ in }
        #expect(choices.session?.model.compression == 0)
    }

    @Test("mobile visibility and recipes persist and filter the actual action provider")
    func savedOptions() throws {
        let suite = "TransfloPreferenceTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let repository = UserDefaultsSettingsRepository(defaults: defaults)
        let conversion = MobileConversionFactory()
        let tools = MobileToolFactory(formats: conversion.catalog, suffixes: LocalizedToolSuffixes(language: .english))
        let model = WheelVisibilityViewModel(choices: ListWheelChoicesUseCase(
            catalog: conversion.catalog, tools: tools.catalog, actions: []
        ), repository: repository)
        let png = try #require(model.groups.flatMap(\.rows).first { $0.id == "format.png" })
        model.setVisible(png, false)
        let base = CatalogWheelOptionsProvider(catalog: conversion.catalog, tools: tools.catalog,
                                               fallback: PreviewWheelOptionsProvider(), engines: tools.engines)
        let provider = VisibilityFilteredWheelOptionsProvider(base: base, visibility: repository)
        let image = URL(fileURLWithPath: "/tmp/source.jpg")
        #expect(!provider.options(for: .convert, items: [image]).contains { $0.id == "format.png" })
        let recipes = RecipesViewModel(repository: repository, formats: conversion.catalog.formats)
        recipes.newRecipe()
        recipes.draft?.name = "Quick export"
        recipes.addStep(.compress)
        recipes.save()
        let fresh = RecipesViewModel(repository: repository, formats: conversion.catalog.formats)
        #expect(fresh.recipes.count == 1 && fresh.recipes.first?.name == "Quick export")
        let recipeProvider = RecipeWheelOptionsProvider(base: base, recipes: repository, catalog: conversion.catalog)
        #expect(recipeProvider.options(for: .tools, items: [image]).contains {
            if case .recipe(let recipe) = $0.kind { return recipe.name == "Quick export" }
            return false
        })
    }
}
