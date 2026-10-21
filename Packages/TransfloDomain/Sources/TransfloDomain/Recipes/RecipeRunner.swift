import Foundation

/// Runs a recipe one file at a time: clones the file into a private folder, runs each step there with
/// the normal runners, then saves only the final result beside the original.
public struct RecipeRunner: WheelJobRunning {
    private let catalog: ConversionCatalog
    private let steps: any WheelJobRunning
    private let workspace: any RecipeWorkspace
    private let preparation: PrepareWheelJobUseCase?

    /// - Parameter steps: Runs each step's option (formats and tools; never another recipe).
    public init(
        catalog: ConversionCatalog,
        steps: any WheelJobRunning,
        workspace: any RecipeWorkspace,
        preparation: PrepareWheelJobUseCase? = nil
    ) {
        self.catalog = catalog
        self.steps = steps
        self.workspace = workspace
        self.preparation = preparation
    }

    public func run(
        _ option: WheelOption,
        on items: [URL],
        progress: @escaping @Sendable (Double) -> Void
    ) async throws(JobError) -> [URL] {
        guard case .recipe(let recipe) = option.kind, recipe.isValid else { throw .unsupported }
        var outputs: [URL] = []
        do throws(JobError) {
            for (index, item) in items.enumerated() {
                if Task.isCancelled { throw .cancelled }
                let base = Double(index) / Double(items.count)
                outputs += try await run(recipe, on: item, index: index) { fraction in
                    progress(base + fraction / Double(items.count))
                }
            }
        } catch {
            throw outputs.isEmpty ? error : .partialFailure(completed: outputs, cause: error)
        }
        progress(1)
        return outputs
    }

    private func run(
        _ recipe: Recipe,
        on item: URL,
        index: Int,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws(JobError) -> [URL] {
        let folder = try workspace.makeFolder()
        defer { workspace.remove(folder) }
        var current = [try workspace.clone(item, into: folder)]
        for (stepIndex, step) in recipe.steps.enumerated() {
            if Task.isCancelled { throw .cancelled }
            guard var stepOption = step.option(catalog: catalog, index: index) else { throw .unsupported }
            if case .format(let target) = stepOption.kind,
               current.allSatisfy({ catalog.format(forFileExtension: $0.pathExtension)?.id == target.id }) {
                progress(Double(stepIndex + 1) / Double(recipe.steps.count))
                continue
            }
            if let preparation { stepOption = preparation.execute(stepOption, items: current).option }
            let share = 1 / Double(recipe.steps.count)
            current = try await steps.run(stepOption, on: current) { fraction in
                progress((Double(stepIndex) + fraction) * share)
            }
            guard !current.isEmpty else { throw .failed }
        }
        let destination = item.deletingLastPathComponent()
        var published: [URL] = []
        do throws(JobError) {
            for result in current {
                if Task.isCancelled { throw .cancelled }
                published.append(try workspace.publish(result, into: destination))
            }
        } catch {
            throw published.isEmpty ? error : .partialFailure(completed: published, cause: error)
        }
        return published
    }
}
