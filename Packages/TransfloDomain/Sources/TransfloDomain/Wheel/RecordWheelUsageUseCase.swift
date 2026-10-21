/// Remembers that an option was used, for "last used first" and frequency ordering.
public struct RecordWheelUsageUseCase: Sendable {
    private let repository: any WheelUsageRepository

    public init(repository: any WheelUsageRepository) {
        self.repository = repository
    }

    public func execute(_ option: WheelOption) {
        var usage = repository.loadWheelUsage()
        usage.record(option)
        repository.saveWheelUsage(usage)
    }
}
