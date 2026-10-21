#if os(macOS)
import Darwin
import Foundation

/// Synchronous helper execution on BlockingWork, with bounded output, time, and cancellation.
enum ProcessRunnerSync {
    struct Output {
        let status: Int32
        let stdout: String
    }

    static func run(
        _ executable: String,
        _ arguments: [String],
        in directory: URL? = nil,
        shouldContinue: () -> Bool = { true }
    ) -> Output? {
        guard !BlockingWork.isCancelled else { return nil }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.currentDirectoryURL = directory
        let capture = FileManager.default.temporaryDirectory
            .appendingPathComponent("transflo-stdout-\(UUID().uuidString)")
        guard FileManager.default.createFile(atPath: capture.path, contents: nil),
              let output = try? FileHandle(forWritingTo: capture) else { return nil }
        defer { try? output.close(); try? FileManager.default.removeItem(at: capture) }
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice
        do { try process.run() } catch { return nil }
        let deadline = Date().addingTimeInterval(300)
        while process.isRunning {
            let size = (try? capture.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            if BlockingWork.isCancelled || Date() >= deadline || size > 16 * 1024 * 1024 || !shouldContinue() {
                process.terminate()
                Thread.sleep(forTimeInterval: 0.2)
                if process.isRunning { kill(process.processIdentifier, SIGKILL) }
                process.waitUntilExit()
                return nil
            }
            Thread.sleep(forTimeInterval: 0.025)
        }
        process.waitUntilExit()
        guard !BlockingWork.isCancelled,
              let data = try? Data(contentsOf: capture), data.count <= 16 * 1024 * 1024 else { return nil }
        // Preserve readable helper output even when diagnostics contain invalid UTF-8.
        // swiftlint:disable:next optional_data_string_conversion
        return Output(status: process.terminationStatus, stdout: String(decoding: data, as: UTF8.self))
    }
}
#endif
