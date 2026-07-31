import SwiftUI

struct MaintenanceView: View {
    @EnvironmentObject var maintenanceManager: MaintenanceManager
    @EnvironmentObject var systemProfiler: SystemProfiler

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Maintenance Tasks")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Tasks actually delete files and free disk space. Admin tasks will prompt for your password.")
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
    }
}

struct TaskList: View {
    @EnvironmentObject var maintenanceManager: MaintenanceManager

    var body: some View {
        List {
            ForEach($maintenanceManager.tasks) { $task in
                HStack(alignment: .top, spacing: 12) {
                    Toggle(isOn: $task.isEnabled) {
                        HStack(alignment: .top) {
                            Image(systemName: task.type.icon)
                                .font(.title2)
                                .frame(width: 28)
                                .foregroundColor(statusColor(task.status))

                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text(task.type.rawValue)
                                        .font(.headline)
                                    if task.type.requiresAdmin {
                                        Image(systemName: "lock.fill")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                            .help("Requires administrator password")
                                    }
                                    statusBadge(task)
                                }
                                Text(task.type.description)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                if let result = task.resultMessage, task.status != .pending {
                                    Text(result)
                                        .font(.caption)
                                        .foregroundColor(task.status == .failed ? .red : .secondary)
                                        .lineLimit(3)
                                }
                                if task.freedBytes > 0 {
                                    Text("Freed \(ByteCountFormatter.string(fromByteCount: task.freedBytes, countStyle: .file))")
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
        }
        .listStyle(.inset)
        .frame(minHeight: 280)
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
    @EnvironmentObject var systemProfiler: SystemProfiler

    var body: some View {
        HStack(spacing: 12) {
            Toggle("Dry run (scan only)", isOn: $maintenanceManager.dryRun)
                .toggleStyle(.checkbox)
                .disabled(maintenanceManager.isRunning)
                .help("Report what would be cleaned without deleting files")

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
                        : "This will empty Trash (if selected) and delete eligible cache/log files. Close other apps first. Admin tasks will ask for your password."
                ) {
                    maintenanceManager.startMaintenance()
                    // Refresh disk space after a short delay when finished is handled by user revisiting dashboard;
                    // kick an early refresh so numbers move after run.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        systemProfiler.refreshSystemInfo()
                    }
                }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(maintenanceManager.isRunning || !maintenanceManager.tasks.contains(where: \.isEnabled))
        }
    }
}
