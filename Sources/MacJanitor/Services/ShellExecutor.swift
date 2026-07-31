import Foundation
import MacJanitorCore

enum ShellExecutor {
    static func execute(_ command: String) async -> (String?, Int32) {
        await ProcessCommandRunner.execute(command)
    }
}

/// Routes admin vs user commands for `CleanupEngine`.
struct AppCommandRunner: CommandRunner {
    func run(_ command: String, asAdmin: Bool) async -> (output: String?, status: Int32) {
        if asAdmin {
            return await AdminExecutor.execute(command)
        }
        return await ProcessCommandRunner.execute(command)
    }
}
