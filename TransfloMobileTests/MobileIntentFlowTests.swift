import Foundation
import Testing
import TransfloData
import TransfloDomain
@testable import TransfloMobile
import UIKit

/// Native execution used by Siri/Shortcuts. System discovery and invocation are separate UI checks.
@Suite("Mobile Shortcuts execution")
struct MobileIntentFlowTests {
    @Test("Convert, Compress and Run Recipe execute native engines and return real files")
    func nativeActions() async throws {
        let suite = "IntentFlow.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let repository = UserDefaultsSettingsRepository(defaults: defaults)
        repository.saveCompressionGoal(.medium)
        let recipe = Recipe(name: "Thumbnail", steps: [.resizeLongEdge(128), .convert(formatID: "png")])
        repository.saveRecipes([recipe])
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let container = MobileContainer(defaults: defaults, documents: root,
                                         historyFile: root.appendingPathComponent("history.json"))
        let dependencies = container.intents
        let services = TransfloIntentServices(catalog: dependencies.catalog, recipes: dependencies.recipes,
                                              run: dependencies.run, preparation: dependencies.preparation)
        let png = try #require(dependencies.catalog.format(FormatID("png")))
        let fixture = try MobileMatrixFixtures.file("jpg")
        let data = try Data(contentsOf: fixture)
        let operations = [WheelOption(.format(png)), WheelOption(.tool(.compress)), WheelOption(.recipe(recipe))]
        for (index, option) in operations.enumerated() {
            let outputs = try await services.perform(option, on: [("photo.jpg", data)])
            defer { outputs.forEach(removeShortcutWorkspace) }
            let file = try #require(outputs.first)
            let image = try #require(UIImage(contentsOfFile: file.path))
            #expect(file.path.contains("transflo-shortcuts-"))
            #expect(image.size == CGSize(width: index == 2 ? 128 : 256, height: index == 2 ? 128 : 256))
            if index != 1 { #expect(file.pathExtension == "png") }
            if index == 1 { #expect(try Data(contentsOf: file).count < data.count) }
            let returned = IntentFiles.outputs(outputs)
            #expect(returned.count == 1 && returned[0].removedOnCompletion)
            #expect(returned[0].data == (try Data(contentsOf: file)))
        }
        #expect(try Data(contentsOf: fixture) == data)
    }

    @Test("Shortcuts rejects missing files and path traversal before executing a tool")
    func invalidInputs() async throws {
        let services = makeServices()
        await #expect(throws: JobError.sourceMissing) {
            try await services.perform(WheelOption(.tool(.rename)), on: [])
        }
        for name in ["..", ".", "../outside.jpg", "folder/shot.jpg", "folder\\shot.jpg", "bad\0.jpg"] {
            await #expect(throws: JobError.unsupported) {
                try await services.perform(WheelOption(.tool(.rename)), on: [(name, Data([1]))])
            }
        }
    }

    private func makeServices() -> TransfloIntentServices {
        let conversion = MobileConversionFactory()
        let tools = MobileToolFactory(formats: conversion.catalog, suffixes: LocalizedToolSuffixes(language: .english))
        let router = WheelJobRouter(conversion: conversion.makeRunner(), tools: tools.makeRunner(),
                                    actions: ActionJobRunner(performers: [:], checker: FileManagerExistenceChecker()))
        return TransfloIntentServices(catalog: conversion.catalog,
                                      recipes: UserDefaultsSettingsRepository(defaults: .standard),
                                      run: RunWheelOptionUseCase(runner: router), preparation: nil)
    }

    private func removeShortcutWorkspace(_ output: URL) {
        var folder = output.deletingLastPathComponent()
        while folder.path != "/" {
            if folder.lastPathComponent.hasPrefix("transflo-shortcuts-") {
                try? FileManager.default.removeItem(at: folder)
                return
            }
            folder.deleteLastPathComponent()
        }
    }
}
