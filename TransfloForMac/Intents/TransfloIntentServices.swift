import Foundation
import TransfloDomain

/// What Shortcuts actions need from the app: the catalog and recipes to offer, and a way to run an option.
/// Registered once at launch with `AppDependencyManager`, the system's way to reach intents, which it
/// creates itself; nothing beyond the intents layer reads it.
final class TransfloIntentServices: Sendable {
    let catalog: ConversionCatalog
    let recipes: any RecipeRepository
    private let run: RunWheelOptionUseCase
    private let preparation: PrepareWheelJobUseCase?

    init(
        catalog: ConversionCatalog,
        recipes: any RecipeRepository,
        run: RunWheelOptionUseCase,
        preparation: PrepareWheelJobUseCase?
    ) {
        self.catalog = catalog
        self.recipes = recipes
        self.run = run
        self.preparation = preparation
    }

    /// Copies `files` into a private folder, runs `option` there, and returns the results.
    func perform(_ option: WheelOption, on files: [(name: String, data: Data)]) async throws(JobError) -> [URL] {
        guard !files.isEmpty else { throw .sourceMissing }
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("transflo-shortcuts-\(UUID().uuidString)", isDirectory: true)
        var inputs: [URL] = []
        var succeeded = false
        defer { if !succeeded { try? FileManager.default.removeItem(at: folder) } }
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            for (index, file) in files.enumerated() {
                if Task.isCancelled { throw JobError.cancelled }
                let name = file.name.isEmpty ? "file" : file.name
                guard name != ".", name != "..", !name.contains("/"), !name.contains("\\"),
                      !name.contains("\0") else { throw JobError.unsupported }
                let inputFolder = folder.appendingPathComponent(String(index), isDirectory: true)
                try FileManager.default.createDirectory(at: inputFolder, withIntermediateDirectories: false)
                let url = inputFolder.appendingPathComponent(name)
                guard url.standardizedFileURL.deletingLastPathComponent() == inputFolder.standardizedFileURL else {
                    throw JobError.unsupported
                }
                try file.data.write(to: url, options: .withoutOverwriting)
                inputs.append(url)
            }
        } catch let error as JobError {
            throw error
        } catch {
            throw .failed
        }
        let prepared = preparation?.execute(option, items: inputs).option ?? option
        let outputs = try await run.execute(prepared, on: inputs) { _ in }
        succeeded = true
        return outputs
    }
}
