import SwiftUI

struct MaintenanceView: View {
    @EnvironmentObject var maintenanceManager: MaintenanceManager
    @EnvironmentObject var systemProfiler: SystemProfiler

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Maintenance Tasks")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Space-freeing tasks delete regenerable junk. Documents, Mail, Photos, Messages, passwords, and browser history are left alone. Admin tasks prompt for your password.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            TaskList()

            StatusView()

            if !maintenanceManager.lastRunSummary.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(maintenanceManager.lastRunSummary)
                        .font(.callout)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.green.opacity(0.12))
                .cornerRadius(8)
            }

            ActionButtons()
        }
        .padding()
        .onAppear {
            systemProfiler.checkTimeMachineStatus()
        }
        .onChange(of: maintenanceManager.isRunning) { running in
            if !running {
                systemProfiler.refreshSystemInfo()
            }
        }
    }
}

struct TaskList: View {
    @EnvironmentObject var maintenanceManager: MaintenanceManager

    var body: some View {
        List {
            Section("Frees disk space") {
                ForEach($maintenanceManager.tasks) { $task in
                    if task.type.freesDiskSpace {
                        taskRow($task)
                    }
                }
            }
            Section("Other maintenance") {
                ForEach($maintenanceManager.tasks) { $task in
                    if !task.type.freesDiskSpace {
                        taskRow($task)
                    }
                }
            }
        }
        .listStyle(.inset)
        .frame(minHeight: 360)
    }

    private func taskRow(_ task: Binding<MaintenanceTask>) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Toggle(isOn: task.isEnabled) {
                HStack(alignment: .top) {
                    Image(systemName: task.wrappedValue.type.icon)
                        .font(.title2)
                        .frame(width: 28)
                        .foregroundColor(statusColor(task.wrappedValue.status))

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(task.wrappedValue.type.rawValue)
                                .font(.headline)
                            if task.wrappedValue.type.requiresAdmin {
                                Image(systemName: "lock.fill")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                    .help("Requires administrator password")
                            }
                            statusBadge(task.wrappedValue)
                        }
                        Text(task.wrappedValue.type.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        if let result = task.wrappedValue.resultMessage, task.wrappedValue.status != .pending {
                            Text(result)
                                .font(.caption)
                                .foregroundColor(task.wrappedValue.status == .failed ? .red : .secondary)
                                .lineLimit(3)
                        }
                        if task.wrappedValue.freedBytes > 0 {
                            Text("\(maintenanceManager.dryRun ? "Would free" : "Freed") \(ByteCountFormatter.string(fromByteCount: task.wrappedValue.freedBytes, countStyle: .file))")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                        }
                    }
                }
            }
            .disabled(maintenanceManager.isRunning)
        }
        .padding(.vertical, 4)
    }

    private func statusColor(_ status: MaintenanceTask.TaskStatus) -> Color {
        switch status {
        case .pending: return .secondary
        case .running: return .blue
        case .completed: return .green
        case .failed: return .red
        case .cancelled: return .orange
        }
    }

    @ViewBuilder
    private func statusBadge(_ task: MaintenanceTask) -> some View {
        switch task.status {
        case .pending:
            EmptyView()
        case .running:
            ProgressView()
                .controlSize(.small)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.caption)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
                .font(.caption)
        case .cancelled:
            Image(systemName: "minus.circle.fill")
                .foregroundColor(.orange)
                .font(.caption)
        }
    }
}

struct StatusView: View {
    @EnvironmentObject var maintenanceManager: MaintenanceManager
    @EnvironmentObject var systemProfiler: SystemProfiler

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProgressView(value: maintenanceManager.overallProgress)
                .progressViewStyle(.linear)
            Text(maintenanceManager.currentTaskDescription)
                .font(.footnote)
                .foregroundColor(.secondary)

            if systemProfiler.timeMachineEnabled {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(.green)
                    Text("Time Machine available — snapshot task can run")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

struct ActionButtons: View {
    @EnvironmentObject var maintenanceManager: MaintenanceManager

    var body: some View {
        HStack(spacing: 12) {
            Toggle("Dry run (scan only)", isOn: $maintenanceManager.dryRun)
                .toggleStyle(.checkbox)
                .disabled(maintenanceManager.isRunning)
                .help("Report what would be cleaned without deleting files")

            Toggle("Deep cache clean", isOn: $maintenanceManager.deepCacheClean)
                .toggleStyle(.checkbox)
                .disabled(maintenanceManager.isRunning)
                .help("Clear user and app caches even if they were used recently")

            Spacer()

            Button("Cancel") {
                maintenanceManager.cancelMaintenance()
            }
            .disabled(!maintenanceManager.isRunning)

            Button(maintenanceManager.dryRun ? "Start Dry Run" : "Start Maintenance") {
                AlertManager.showConfirmation(
                    title: maintenanceManager.dryRun ? "Run dry scan?" : "Start real cleanup?",
                    message: maintenanceManager.dryRun
                        ? "No files will be deleted. MacJanitor will only report what would be cleaned."
                        : "This deletes Trash and the other selected junk: caches, browser caches, old logs, temporary files, and developer build products you enabled. Documents, Mail, Photos, Messages, passwords, and browser history stay. Admin tasks will ask for your password."
                ) {
                    maintenanceManager.startMaintenance()
                }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(maintenanceManager.isRunning || !maintenanceManager.tasks.contains(where: \.isEnabled))
        }
    }
}
