import Foundation
import SwiftUI
import MacJanitorCore

@MainActor
final class MaintenanceManager: ObservableObject {
    @Published var tasks: [MaintenanceTask] = MaintenanceTaskType.allCases.map { MaintenanceTask(type: $0) }
    @Published var isRunning = false
    @Published var overallProgress: Double = 0.0
    @Published var currentTaskDescription: String = "Ready to start"
    @Published var requiresReboot = false
    @Published var operationLogger = OperationLogger()
    @Published var dryRun = false
    @Published var lastRunFreedBytes: Int64 = 0
    @Published var lastRunSummary: String = ""

    private var taskQueue: [MaintenanceTask] = []
    private var currentTaskIndex = 0
    private var taskStartTime: Date?
    private var runFreedBytes: Int64 = 0

    func startMaintenance() {
        guard !isRunning else { return }

        taskQueue = tasks.filter(\.isEnabled)
        guard !taskQueue.isEmpty else { return }

        isRunning = true
        requiresReboot = false
        overallProgress = 0.0
        currentTaskIndex = 0
        runFreedBytes = 0
        lastRunFreedBytes = 0
        lastRunSummary = ""

        for i in tasks.indices {
            tasks[i].status = .pending
            tasks[i].progress = 0.0
            tasks[i].errorMessage = nil
            tasks[i].freedBytes = 0
            tasks[i].resultMessage = nil
        }

        runNextTask()
    }

    func cancelMaintenance() {
        guard isRunning else { return }

        if let taskIndex = tasks.firstIndex(where: { $0.status == .running }) {
            tasks[taskIndex].status = .cancelled
            tasks[taskIndex].resultMessage = "Cancelled"
        }

        isRunning = false
        currentTaskDescription = "Maintenance cancelled"
        lastRunSummary = "Cancelled after freeing \(ByteCountFormatter.string(fromByteCount: runFreedBytes, countStyle: .file))"
        lastRunFreedBytes = runFreedBytes
    }

    private func runNextTask() {
        guard currentTaskIndex < taskQueue.count, isRunning else {
            finishMaintenance()
            return
        }

        let queued = taskQueue[currentTaskIndex]
        guard let taskIndex = tasks.firstIndex(where: { $0.type == queued.type }) else {
            currentTaskIndex += 1
            runNextTask()
            return
        }

        tasks[taskIndex].status = .running
        currentTaskDescription = tasks[taskIndex].type.description
        taskStartTime = Date()

        let taskType = tasks[taskIndex].type
        let useDryRun = dryRun
        let started = taskStartTime ?? Date()

        Task { [weak self] in
            let engine = CleanupEngine(
                runner: AppCommandRunner(),
                dryRun: useDryRun
            )
            let result = await engine.perform(taskType.coreKind)
            let duration = Date().timeIntervalSince(started)
            await MainActor.run {
                self?.apply(result: result, to: taskIndex, duration: duration, command: result.commandSummary)
            }
        }
    }

    private func apply(result: CleanupResult, to taskIndex: Int, duration: TimeInterval, command: String) {
        tasks[taskIndex].status = result.success ? .completed : .failed
        tasks[taskIndex].progress = 1.0
        tasks[taskIndex].freedBytes = result.freedBytes
        tasks[taskIndex].resultMessage = result.message
        tasks[taskIndex].errorMessage = result.success ? nil : result.message

        if result.success {
            runFreedBytes += result.freedBytes
            if tasks[taskIndex].type.requiresReboot {
                requiresReboot = true
            }
        }

        operationLogger.logTask(
            task: tasks[taskIndex].type.rawValue,
            command: command.isEmpty ? tasks[taskIndex].type.rawValue : command,
            output: result.message,
            success: result.success,
            duration: duration,
            freedBytes: result.freedBytes
        )

        currentTaskIndex += 1
        overallProgress = Double(currentTaskIndex) / Double(taskQueue.count)
        runNextTask()
    }

    private func finishMaintenance() {
        isRunning = false
        lastRunFreedBytes = runFreedBytes
        let freedText = ByteCountFormatter.string(fromByteCount: runFreedBytes, countStyle: .file)
        if dryRun {
            currentTaskDescription = "Dry run complete"
            lastRunSummary = "Dry run finished (no files deleted)"
        } else {
            currentTaskDescription = "Maintenance complete — freed \(freedText)"
            lastRunSummary = "Freed \(freedText) across completed tasks"
        }

        if requiresReboot {
            currentTaskDescription += " (reboot recommended)"
        }
    }
}
