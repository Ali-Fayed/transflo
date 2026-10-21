#if os(macOS)
import Darwin
import Foundation

/// Runs a helper executable with an argument array (never a shell string), streaming its output
/// line by line. Cancelling the calling task terminates the process.
///
/// Output is drained with async line sequences until EOF, and the exit status comes from a
/// buffered stream, so no callback is left firing after the process ends.
enum ProcessRunner {
    /// - Returns: The exit status, or `nil` if the process could not be launched.
    static func run(
        executable: URL,
        arguments: [String],
        currentDirectory: URL? = nil,
        shouldContinue: @escaping @Sendable () -> Bool = { true },
        onStdoutLine: @escaping @Sendable (String) -> Void,
        onStderrLine: @escaping @Sendable (String) -> Void
    ) async -> Int32? {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.currentDirectoryURL = currentDirectory
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        process.standardInput = FileHandle.nullDevice
        let (exits, exitContinuation) = AsyncStream.makeStream(of: Int32.self, bufferingPolicy: .bufferingNewest(1))
        process.terminationHandler = { finished in
            exitContinuation.yield(finished.terminationStatus)
            exitContinuation.finish()
        }
        do {
            try process.run()
        } catch {
            return nil
        }
        // Our copies of the write ends must close, or the readers would never see EOF.
        try? stdout.fileHandleForWriting.close()
        try? stderr.fileHandleForWriting.close()
        let handle = ProcessHandle(process)
        let watchdog = Task.detached {
            let deadline = ContinuousClock.now + .seconds(3600)
            while process.isRunning, !Task.isCancelled {
                if ContinuousClock.now >= deadline || !shouldContinue() { handle.terminate(); return }
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
        defer { watchdog.cancel() }
        return await withTaskCancellationHandler {
            async let drainedOut: Void = drain(stdout.fileHandleForReading, into: onStdoutLine)
            async let drainedErr: Void = drain(stderr.fileHandleForReading, into: onStderrLine)
            _ = await (drainedOut, drainedErr)
            for await status in exits {
                return status
            }
            return nil
        } onCancel: {
            handle.terminate()
        }
    }

    // Helper diagnostics may contain invalid UTF-8; retain readable text with replacement characters.
    // swiftlint:disable optional_data_string_conversion
    private static func drain(_ handle: FileHandle, into onLine: @Sendable (String) -> Void) async {
        do {
            var line: [UInt8] = []
            for try await byte in handle.bytes {
                if byte == 10 {
                    onLine(String(decoding: line, as: UTF8.self))
                    line.removeAll(keepingCapacity: true)
                } else if line.count < 65_536 { line.append(byte) }
            }
            if !line.isEmpty { onLine(String(decoding: line, as: UTF8.self)) }
        } catch {
            // A read error just ends the stream; the exit status still decides success.
        }
    }
    // swiftlint:enable optional_data_string_conversion
}

// @unchecked: `Process.terminate()` is safe to call from any thread.
/// Lets the cancellation handler reach the process.
private final class ProcessHandle: @unchecked Sendable {
    private let process: Process

    init(_ process: Process) {
        self.process = process
    }

    func terminate() {
        guard process.isRunning else { return }
        process.terminate()
        // Encoders can keep flushing after SIGTERM, or a helper can ignore it entirely.
        // The destination is private staging, so cancellation must bound that work.
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + .milliseconds(200)) { [self] in
            if process.isRunning { kill(process.processIdentifier, SIGKILL) }
        }
    }
}
#endif
