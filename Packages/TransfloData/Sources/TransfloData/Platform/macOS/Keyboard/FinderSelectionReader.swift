#if os(macOS)
import Foundation
import TransfloDomain

/// Reads Finder's selection through `osascript`, one POSIX path per line (folders end in `/`).
/// The first use asks for Automation consent to control Finder.
public struct FinderSelectionReader: FinderSelectionReading {
    static let script = [
        "set output to \"\"",
        "tell application \"Finder\" to set picked to selection as alias list",
        "repeat with anItem in picked",
        "set output to output & POSIX path of anItem & linefeed",
        "end repeat",
        "return output"
    ]

    public init() {}

    public func selection() async throws(JobError) -> [URL] {
        let lines = Collector()
        let errors = Collector()
        let status = await ProcessRunner.run(
            executable: URL(fileURLWithPath: "/usr/bin/osascript"),
            arguments: Self.script.flatMap { ["-e", $0] },
            onStdoutLine: lines.append,
            onStderrLine: errors.append
        )
        guard let status else { throw .unsupported }
        guard status == 0 else { throw IWorkAutomation.error(from: errors.lines) }
        return Self.urls(from: lines.lines)
    }

    /// Absolute paths become file URLs; blank or relative lines are ignored.
    static func urls(from lines: [String]) -> [URL] {
        lines.map { $0.trimmingCharacters(in: .newlines) }
            .filter { $0.hasPrefix("/") }
            .map { URL(fileURLWithPath: $0, isDirectory: $0.hasSuffix("/")) }
    }
}
#endif
