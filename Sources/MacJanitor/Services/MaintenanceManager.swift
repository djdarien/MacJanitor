import Foundation
import SwiftUI

@MainActor
class MaintenanceManager: ObservableObject {
    @Published var tasks: [MaintenanceTask] = MaintenanceTaskType.allCases.map { MaintenanceTask(type: $0) }
    @Published var isRunning = false
    @Published var overallProgress: Double = 0.0
    @Published var currentTaskDescription: String = "Ready to start"
    @Published var requiresReboot = false
    
    private var taskQueue: [MaintenanceTask] = []
    private var currentTaskIndex = 0
    
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
            
            Task {
                let result = await executeTask(tasks[taskIndex].type)
                
                DispatchQueue.main.async {
                    self.tasks[taskIndex].status = result ? .completed : .failed
                    self.tasks[taskIndex].progress = 1.0
                    
                    if result && self.tasks[taskIndex].type.requiresReboot {
                        self.requiresReboot = true
                    }
                    
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
    
    private func executeTask(_ type: MaintenanceTaskType) async -> Bool {
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
            command = "echo 'Font cache cleanup requires admin privileges - skipped'"
        case .logCleanup:
            command = "echo 'Log cleanup requires admin privileges - skipped'"
        case .trashEmpty:
            command = "rm -rf ~/.Trash/*"
        case .memoryPurge:
            command = "echo 'Memory purge requires admin privileges - skipped'"
        case .safariCleanup:
            command = "rm -rf ~/Library/Caches/com.apple.Safari/* && rm -rf ~/Library/Caches/Metadata/Safari/*"
        case .systemCacheCleanup:
            command = "echo 'System cache cleanup requires admin privileges - skipped'"
        case .userCacheCleanup:
            command = "rm -rf ~/Library/Caches/*"
        }
        
        let (output, status) = await ShellExecutor.execute(command)
        
        if status != 0 {
            print("Error executing task \(type.rawValue): \(output ?? "Unknown error")")
        }
        
        return status == 0
    }
}
