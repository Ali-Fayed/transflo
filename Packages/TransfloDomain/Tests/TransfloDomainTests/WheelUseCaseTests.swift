import Foundation
import Testing
import TransfloDomain
import TransfloDomainTestSupport

@Suite("Wheel use cases")
struct WheelUseCaseTests {
    private let file = URL(fileURLWithPath: "/tmp/photo.heic")

    @Test("options come from the provider for the requested wheel")
    func resolvesOptions() {
        let tools = [WheelOption(.tool(.crop))]
        let sut = ResolveWheelOptionsUseCase(provider: StubWheelOptionsProvider([.tools: tools]))
        #expect(sut.execute(wheel: .tools, items: [file]) == tools)
        #expect(sut.execute(wheel: .convert, items: [file]).isEmpty)
    }

    @Test("long option lists pass through whole; the wheel pages them")
    func keepsAllOptions() {
        let many = ToolKind.allCases.map { WheelOption(.tool($0)) }
        let sut = ResolveWheelOptionsUseCase(provider: StubWheelOptionsProvider([.tools: many]))
        #expect(sut.execute(wheel: .tools, items: [file]) == many)
    }

    @Test("no items means no options")
    func noItems() {
        let provider = StubWheelOptionsProvider([.actions: [WheelOption(.action(.copy))]])
        let sut = ResolveWheelOptionsUseCase(provider: provider)
        #expect(sut.execute(wheel: .actions, items: []).isEmpty)
    }

    @Test("option identifiers are stable and distinct")
    func optionIdentifiers() {
        #expect(WheelOption(.format(CatalogFixtures.png)).id == "format.png")
        #expect(WheelOption(.tool(.crop)).id == "tool.crop")
        #expect(WheelOption(.action(.copyPath)).id == "action.copyPath")
    }

    @Test("running an option forwards it to the runner and returns its outputs")
    func runsOption() async throws {
        let output = URL(fileURLWithPath: "/tmp/photo 2.heic")
        let runner = FakeWheelJobRunner(result: .success([output]))
        let option = WheelOption(.format(CatalogFixtures.png))
        let result = try await RunWheelOptionUseCase(runner: runner).execute(option, on: [file])
        #expect(result == [output])
        #expect(runner.receivedCalls == [.init(option: option, items: [file])])
    }

    @Test("runner failures propagate", arguments: [JobError.sourceMissing, .destinationUnavailable, .failed])
    func runFails(error: JobError) async {
        let sut = RunWheelOptionUseCase(runner: FakeWheelJobRunner(result: .failure(error)))
        await #expect(throws: error) { try await sut.execute(WheelOption(.tool(.crop)), on: [file]) }
    }

    @Test("an empty selection never reaches the runner")
    func emptySelection() async throws {
        let runner = FakeWheelJobRunner()
        #expect(try await RunWheelOptionUseCase(runner: runner).execute(WheelOption(.action(.copy)), on: []).isEmpty)
        #expect(runner.receivedCalls.isEmpty)
    }
}
