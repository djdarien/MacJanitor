import Foundation

class AdminExecutor {
    static func execute(_ command: String) async -> (String?, Int32) {
        // Escape special characters for AppleScript to prevent injection
        let escapedCommand = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")
            .replacingOccurrences(of: "!", with: "\\!")
        
        let appleScript = """
        do shell script "\(escapedCommand)" with administrator privileges
        """

        let script = NSAppleScript(source: appleScript)
        var error: NSDictionary?

        let result = script?.executeAndReturnError(&error)

        if let error = error {
            let errorMessage = error["NSAppleScriptErrorMessage"] as? String ?? "Unknown error"
            return (errorMessage, -1)
        }

        let output = result?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (output, 0)
    }
}