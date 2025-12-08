import SwiftUI

struct MaintenanceView: View {
    @EnvironmentObject var maintenanceManager: MaintenanceManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Maintenance Tasks")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            TaskList()
            
            StatusView()
            
            ActionButtons()
        }
        .padding()
    }
}

struct TaskList: View {
    @EnvironmentObject var maintenanceManager: MaintenanceManager
    
    var body: some View {
        List($maintenanceManager.tasks) { $task in
            Toggle(isOn: $task.isEnabled) {
                HStack {
                    Image(systemName: task.type.icon)
                        .font(.title2)
                        .frame(width: 30)
                    VStack(alignment: .leading) {
                        Text(task.type.rawValue)
                            .font(.headline)
                        Text(task.type.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

struct StatusView: View {
    @EnvironmentObject var maintenanceManager: MaintenanceManager
    
    var body: some View {
        VStack {
            ProgressView(value: maintenanceManager.overallProgress)
                .progressViewStyle(LinearProgressViewStyle())
            Text(maintenanceManager.currentTaskDescription)
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }
}

struct ActionButtons: View {
    @EnvironmentObject var maintenanceManager: MaintenanceManager
    
    var body: some View {
        HStack {
            Button(action: {
                AlertManager.showConfirmation(
                    title: "Are you sure?",
                    message: "This will perform maintenance tasks on your system. It is recommended to close all other applications."
                ) {
                    maintenanceManager.startMaintenance()
                }
            }) {
                Text("Start Maintenance")
            }
            .disabled(maintenanceManager.isRunning)
            
            Button(action: {
                maintenanceManager.cancelMaintenance()
            }) {
                Text("Cancel")
            }
            .disabled(!maintenanceManager.isRunning)
        }
    }
}