import Foundation

struct SystemInfo: Identifiable, Codable {
    let id = UUID()
    let macOSVersion: String
    let buildVersion: String
    let architecture: String
    let model: String
    let processor: String
    let memory: String
    let diskSpace: DiskSpaceInfo
    let batteryLevel: Double?
    let isOnBatteryPower: Bool
    
    enum CodingKeys: String, CodingKey {
        case macOSVersion, buildVersion, architecture, model, processor, memory, diskSpace, batteryLevel, isOnBatteryPower
    }
    
    static let `default` = SystemInfo(
        macOSVersion: "Unknown",
        buildVersion: "Unknown",
        architecture: "Unknown",
        model: "Unknown",
        processor: "Unknown",
        memory: "Unknown",
        diskSpace: DiskSpaceInfo(total: 0, available: 0, used: 0),
        batteryLevel: nil,
        isOnBatteryPower: false
    )
}

struct DiskSpaceInfo: Codable {
    let total: Int64
    let available: Int64
    let used: Int64
    
    var usedPercentage: Double {
        guard total > 0 else { return 0 }
        return Double(used) / Double(total) * 100
    }
    
    var availablePercentage: Double {
        guard total > 0 else { return 0 }
        return Double(available) / Double(total) * 100
    }
}