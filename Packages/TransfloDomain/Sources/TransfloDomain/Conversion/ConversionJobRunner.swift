import Foundation

/// Runs Convert-wheel jobs: resolves each file's path, picks an engine, names the output,
/// converts, and preserves completed results when a later item fails.
///
/// Up to `maximumConcurrentItems` files convert at once (audio and video use at most half, since each
/// ffmpeg encode is already multi-threaded). Names are reserved for the whole batch first, so parallel
/// files never collide; outputs keep the order of the dropped files.
public struct ConversionJobRunner: WheelJobRunning {
    private let catalog: ConversionCatalog
    private let engines: [EngineID: any ConversionEngine]
    private let naming: NameOutputFileUseCase
    private let maximumConcurrentItems: Int

    public init(
        catalog: ConversionCatalog,
        engines: [any ConversionEngine],
        naming: NameOutputFileUseCase,
        remover: any FileRemoving,
        maximumConcurrentItems: Int = 1
    ) {
        self.catalog = catalog
        self.engines = Dictionary(engines.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        self.naming = naming
        self.maximumConcurrentItems = max(1, maximumConcurrentItems)
        // Engines own and clean private staging; final paths may belong to another writer.
    }

    public func run(
        _ option: WheelOption,
        on items: [URL],
        progress: @escaping @Sendable (Double) -> Void
    ) async throws(JobError) -> [URL] {
        guard case .format(let target) = option.kind else { throw .unsupported }
        let batchNaming = naming.forBatch()
        var jobs: [(request: ConversionRequest, engine: any ConversionEngine)] = []
        var preparationError: JobError?
        // Files after the first one that cannot be converted are left alone, as when converting in order.
        for source in items {
            do throws(JobError) {
                let request = try makeRequest(source: source, target: target, naming: batchNaming)
                jobs.append((request, try engine(for: request)))
            } catch {
                preparationError = error
                break
            }
        }
        let batch = BatchProgress(count: items.count, report: progress)
        let outcome = await convert(jobs, width: width(for: jobs.map(\.request)), progress: batch)
        let outputs = outcome.outputs
        if let error = outcome.error ?? preparationError {
            throw outputs.isEmpty ? error : .partialFailure(completed: outputs, cause: error)
        }
        progress(1)
        return outputs
    }

    private func width(for requests: [ConversionRequest]) -> Int {
        let media = requests.contains { [.audio, .video].contains($0.sourceFormat.family) }
        return media ? max(1, maximumConcurrentItems / 2) : maximumConcurrentItems
    }

    /// Converts `jobs` at most `width` at a time. Stops starting new files after the first failure or
    /// cancellation; files already running finish, and their results are kept.
    private func convert(
        _ jobs: [(request: ConversionRequest, engine: any ConversionEngine)],
        width: Int,
        progress: BatchProgress
    ) async -> (outputs: [URL], error: JobError?) {
        guard width > 1, jobs.count > 1 else { return await convertInOrder(jobs, progress: progress) }
        var results: [Int: [URL]] = [:]
        var failure: (index: Int, error: JobError)?
        await withTaskGroup(of: (Int, Result<[URL], JobError>).self) { group in
            var next = 0
            func startNext() {
                guard next < jobs.count, failure == nil, !Task.isCancelled else { return }
                let index = next
                let job = jobs[index]
                next += 1
                group.addTask {
                    if Task.isCancelled { return (index, .failure(.cancelled)) }
                    do throws(JobError) {
                        return (index, .success(try await job.engine.convert(job.request) { fraction in
                            progress.update(index, to: fraction)
                        }))
                    } catch {
                        return (index, .failure(error))
                    }
                }
            }
            for _ in 0..<width { startNext() }
            for await (index, result) in group {
                switch result {
                case .success(let urls):
                    results[index] = urls
                    progress.update(index, to: 1)
                case .failure(let error):
                    if failure.map({ index < $0.index }) ?? true { failure = (index, error) }
                }
                startNext()
            }
        }
        if failure == nil, Task.isCancelled, results.count < jobs.count { failure = (jobs.count, .cancelled) }
        let ordered = results.keys.sorted().flatMap { results[$0] ?? [] }
        return (ordered, failure?.error)
    }

    /// One file at a time in the job's own task, so cancelling the job stops before the next file.
    private func convertInOrder(
        _ jobs: [(request: ConversionRequest, engine: any ConversionEngine)],
        progress: BatchProgress
    ) async -> (outputs: [URL], error: JobError?) {
        var outputs: [URL] = []
        for (index, job) in jobs.enumerated() {
            if Task.isCancelled { return (outputs, .cancelled) }
            do throws(JobError) {
                outputs += try await job.engine.convert(job.request) { progress.update(index, to: $0) }
                progress.update(index, to: 1)
            } catch {
                return (outputs, error)
            }
        }
        return (outputs, nil)
    }

    private func makeRequest(
        source: URL,
        target: FormatDescriptor,
        naming: NameOutputFileUseCase
    ) throws(JobError) -> ConversionRequest {
        guard let sourceFormat = catalog.format(forFileExtension: source.pathExtension) else { throw .unsupported }
        let destination = try naming.execute(for: source, pathExtension: target.outputExtension)
        return ConversionRequest(
            source: source,
            destination: destination,
            sourceFormat: sourceFormat,
            targetFormat: target
        )
    }

    private func engine(for request: ConversionRequest) throws(JobError) -> any ConversionEngine {
        guard let path = catalog.path(from: request.sourceFormat.id, to: request.targetFormat.id) else {
            throw .unsupported
        }
        let candidate = path.engines.lazy
            .compactMap { engines[$0] }
            .first { $0.canConvert(from: request.sourceFormat, to: request.targetFormat) }
        guard let candidate else { throw .unsupported }
        return candidate
    }
}
