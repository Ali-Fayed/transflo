import Foundation

/// A saved chain of steps that runs as one option on the Tools wheel: for example, convert to JPG,
/// resize to 2048 px, remove metadata, then rename.
public struct Recipe: Sendable, Hashable, Codable, Identifiable {
    public let id: UUID
    public var name: String
    public var steps: [RecipeStep]

    public init(id: UUID = UUID(), name: String, steps: [RecipeStep]) {
        self.id = id
        self.name = name
        self.steps = steps
    }

    /// A recipe needs a name and at least one step, and a rename may only come last (it names the result).
    public var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !steps.isEmpty
            && steps.dropLast().allSatisfy { !$0.isRename } && steps.allSatisfy(\.isValid)
    }
}
