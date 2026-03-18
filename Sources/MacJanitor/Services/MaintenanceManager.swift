import Foundation
import SwiftUI

@MainActor
class MaintenanceManager: ObservableObject {
    @Published var tasks: [MaintenanceTask] = MaintenanceTaskType.allCases.map { MaintenanceTask(type: $0) }
    @Published var isRunning = false
    @Published var overallProgress: Double = 0.0
    @Published var currentTaskDescription: String = "Ready to start"
    @Published var requiresReboot = false
    @Published var operationLogger = OperationLogger()
    
    private var taskQueue: [MaintenanceTask] = []
    private var currentTaskIndex = 0
    private var taskStartTime: Date?
    
    func startMaintenance() {
        guard !isRunning else { return }
        
        taskQueue = tasks.filter { $0.isEnabled }
        guard !taskQueue.isEmpty else { return }
        
        isRunning = true
        requiresReboot = false
        overallProgress = 0.0
        currentTaskIndex = 0
        
        for i in tasks.indices {
            tasks[i].status = .pending
            tasks[i].progress = 0.0
        }
        
        runNextTask()
    }
    
    func cancelMaintenance() {
        guard isRunning else { return }
        
        if let taskIndex = tasks.firstIndex(where: { $0.status == .running }) {
            tasks[taskIndex].status = .cancelled
        }
        
        isRunning = false
        currentTaskDescription = "Maintenance cancelled"
    }
    
    private func runNextTask() {
        guard currentTaskIndex < taskQueue.count, isRunning else {
            finishMaintenance()
            return
        }
        
        var task = taskQueue[currentTaskIndex]
        if let taskIndex = tasks.firstIndex(where: { $0.type == task.type }) {
            tasks[taskIndex].status = .running
            currentTaskDescription = task.type.description
            taskStartTime = Date()
            
            Task {
                let (result, output, command) = await self.executeTaskWithOutput(self.tasks[taskIndex].type)
                let duration = Date().timeIntervalSince(self.taskStartTime ?? Date())
                
                DispatchQueue.main.async {
                    self.tasks[taskIndex].status = result ? .completed : .failed
                    self.tasks[taskIndex].progress = 1.0
                    
                    if result && self.tasks[taskIndex].type.requiresReboot {
                        self.requiresReboot = true
                    }
                    
                    self.operationLogger.logTask(
                        task: self.tasks[taskIndex].type.rawValue,
                        command: command,
                        output: output ?? "No output",
                        success: result,
                        duration: duration
                    )
                    
                    self.currentTaskIndex += 1
                    self.overallProgress = Double(self.currentTaskIndex) / Double(self.taskQueue.count)
                    self.runNextTask()
                }
            }
        }
    }
    
    private func finishMaintenance() {
        isRunning = false
        currentTaskDescription = "Maintenance complete"
        
        if requiresReboot {
            // Present a dialog to the user to restart
        }
    }
    
    private func executeTaskWithOutput(_ type: MaintenanceTaskType) async -> (Bool, String?, String) {
        let command: String
        switch type {
        case .cacheCleanup:
            command = "rm -rf ~/Library/Caches/*"
        case .systemOptimization:
            command = "defaults write NSGlobalDomain NSWindowResizeTime -float 0.001 && defaults write com.apple.Dock autohide-delay -float 0 && defaults write com.apple.finder DisableAllAnimations -bool true && defaults write com.apple.dock expose-animation-duration -float 0.1 && defaults write com.apple.dock launchanim -bool false"
        case .diskMaintenance:
            command = "diskutil verifyVolume /"
        case .dnsFlush:
            command = "dscacheutil -flushcache && killall -HUP mDNSResponder"
        case .fontCacheCleanup:
            command = "atsutil databases -remove"
        case .logCleanup:
            command = """
            /usr/bin/find /var/log -type f \\( -name "*.log" -o -name "*.gz" -o -name "*.old" \\) -mtime +7 -delete 2>/dev/null; 
            echo "Logs older than 7 days cleaned"
            """
        case .trashEmpty:
            command = """
            /usr/bin/find ~/.Trash -maxdepth 1 -not -path ~/.Trash -delete 2>/dev/null; 
            for volume in /Volumes/*; do 
                if [ -d "$volume/.Trashed" ]; then 
                    /usr/bin/find "$volume/.Trashed" -maxdepth 1 -not -path "$volume/.Trashed" -delete 2>/dev/null; 
                fi; 
            done; 
            echo "Trash emptied on all volumes"
            """
        case .memoryPurge:
            command = "purge"
        case .safariCleanup:
            command = "rm -rf ~/Library/Caches/com.apple.Safari/* && rm -rf ~/Library/Caches/Metadata/Safari/*"
        case .systemCacheCleanup:
            command = """
            /usr/bin/find /Library/Caches -type f -mtime +7 -delete 2>/dev/null; 
            /usr/bin/find /Library/Caches -type d -empty -delete 2>/dev/null; 
            echo "System caches older than 7 days cleaned"
            """
        case .userCacheCleanup:
            command = """
            /usr/bin/find ~/Library/Caches -type f -mtime +7 -delete 2>/dev/null; 
            /usr/bin/find ~/Library/Caches -type d -empty -delete 2>/dev/null; 
            echo "User caches older than 7 days cleaned"
            """
        case .timeMachineSnapshot:
            command = """
            if tmutil istimeMachineEnabled 2>/dev/null; then 
                tmutil localsnapshot 2>/dev/null && echo "Time Machine snapshot created" || echo "Snapshot failed"; 
            else 
                echo "Time Machine not enabled"; 
            fi
            """
        }

        let (output, status): (String?, Int32)
        if type.requiresAdmin {
            (output, status) = await AdminExecutor.execute(command)
        } else {
            (output, status) = await ShellExecutor.execute(command)
        }

        if status != 0 {
            print("Error executing task \(type.rawValue): \(output ?? "Unknown error")")
        }

        return (status == 0, output, command)
    }
    
    private func executeTask(_ type: MaintenanceTaskType) async -> Bool {
        let (result, _, _) = await executeTaskWithOutput(type)
        return result
    }
}
