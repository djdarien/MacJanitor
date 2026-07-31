import Foundation
import AppKit

/// Runs shell scripts with an admin password dialog via AppleScript.
///
/// Scripts are written to a temp file and executed, avoiding brittle quoting/escaping
/// that previously broke `$variables` and multi-line cleanup commands.
enum AdminExecutor {
    static func execute(_ command: String) async -> (String?, Int32) {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: runSynchronously(command))
            }
        }
    }

    private static func runSynchronously(_ command: String) -> (String?, Int32) {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("macjanitor-\(UUID().uuidString).sh")

        let scriptBody = """
        #!/bin/zsh
        setopt NULL_GLOB
        setopt NO_NOMATCH
        set -o pipefail
        \(command)
        """

        do {
            try scriptBody.write(to: tempURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o700],
                ofItemAtPath: tempURL.path
            )
        } catch {
            return ("Failed to write temp script: \(error.localizedDescription)", -1)
        }

        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        // Quote path for AppleScript string; run script file so shell syntax is intact.
        let escapedPath = tempURL.path
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let appleScript = """
        do shell script "\"\(escapedPath)\"" with administrator privileges
        """

        var error: NSDictionary?
        guard let script = NSAppleScript(source: appleScript) else {
            return ("Failed to create AppleScript", -1)
        }

        let result = script.executeAndReturnError(&error)

        if let error {
            let message = (error["NSAppleScriptErrorMessage"] as? String)
                ?? (error["NSAppleScriptErrorBriefMessage"] as? String)
                ?? "Authorization failed or command error"
            let number = (error["NSAppleScriptErrorNumber"] as? Int) ?? -1
            // -128 is user cancelled
            return (message, Int32(number == -128 ? 126 : number))
        }

        let output = result.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (output, 0)
    }
}
