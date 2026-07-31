import Foundation

/// Abstraction over shell / privileged execution so the engine is testable.
public protocol CommandRunner: Sendable {
    func run(_ command: String, asAdmin: Bool) async -> (output: String?, status: Int32)
}

/// Runs commands via `/bin/zsh -c` without privilege escalation.
public struct ProcessCommandRunner: CommandRunner {
    public init() {}

    public func run(_ command: String, asAdmin: Bool) async -> (output: String?, status: Int32) {
        // Admin path is handled by the app layer (AdminExecutor). Core only runs non-admin.
        _ = asAdmin
        return await Self.execute(command)
    }

    public static func execute(_ command: String) async -> (output: String?, status: Int32) {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let pipe = Pipe()

                process.standardOutput = pipe
                process.standardError = pipe
                process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                // -c runs the script; enable nullglob so empty globs do not fail
                process.arguments = ["-c", "setopt NULL_GLOB; setopt NO_NOMATCH; \(command)"]
                process.environment = ProcessInfo.processInfo.environment

                do {
                    try process.run()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()
                    let output = String(data: data, encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    continuation.resume(returning: (output, process.terminationStatus))
                } catch {
                    continuation.resume(returning: (error.localizedDescription, -1))
                }
            }
        }
    }
}

/// Test double that records commands and returns canned results.
public final class MockCommandRunner: CommandRunner, @unchecked Sendable {
    public struct Call: Equatable {
        public let command: String
        public let asAdmin: Bool
    }

    public private(set) var calls: [Call] = []
    public var handler: (@Sendable (String, Bool) -> (String?, Int32))?

    public init(handler: (@Sendable (String, Bool) -> (String?, Int32))? = nil) {
        self.handler = handler
    }

    public func run(_ command: String, asAdmin: Bool) async -> (output: String?, status: Int32) {
        calls.append(Call(command: command, asAdmin: asAdmin))
        if let handler {
            return handler(command, asAdmin)
        }
        return ("ok", 0)
    }
}
