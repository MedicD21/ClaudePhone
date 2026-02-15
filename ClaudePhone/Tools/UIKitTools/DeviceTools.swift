import Foundation
import UIKit

// MARK: - Get Device Info
struct GetDeviceInfoTool: ClaudeTool {
    let name = "get_device_info"
    let description = "Get comprehensive information about the current iOS device"
    let category = ToolCategory.uiKit

    let parameters: [ToolParameter] = []
    let requiredParams: [String] = []

    @MainActor
    func execute(with arguments: [String: Any]) async throws -> String {
        let device = UIDevice.current
        let processInfo = ProcessInfo.processInfo
        let screen = UIScreen.main

        var result = "Device Information:\n"
        result += "- Name: \(device.name)\n"
        result += "- Model: \(device.model)\n"
        result += "- System: \(device.systemName) \(device.systemVersion)\n"
        result += "- Identifier: \(device.identifierForVendor?.uuidString ?? "Unknown")\n"

        result += "\nHardware:\n"
        result += "- Processor Count: \(processInfo.processorCount)\n"
        result += "- Active Processors: \(processInfo.activeProcessorCount)\n"
        result += "- Physical Memory: \(processInfo.physicalMemory / (1024 * 1024 * 1024)) GB\n"

        result += "\nDisplay:\n"
        result += "- Screen Size: \(Int(screen.bounds.width)) x \(Int(screen.bounds.height)) points\n"
        result += "- Native Scale: \(screen.nativeScale)x\n"
        result += "- Brightness: \(Int(screen.brightness * 100))%\n"

        device.isBatteryMonitoringEnabled = true
        result += "\nBattery:\n"
        result += "- Level: \(Int(device.batteryLevel * 100))%\n"
        result += "- State: \(device.batteryState.displayName)\n"

        result += "\nStorage:\n"
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()) {
            if let totalSpace = attrs[.systemSize] as? Int64 {
                result += "- Total: \(totalSpace / (1024 * 1024 * 1024)) GB\n"
            }
            if let freeSpace = attrs[.systemFreeSize] as? Int64 {
                result += "- Available: \(freeSpace / (1024 * 1024 * 1024)) GB\n"
            }
        }

        return result
    }
}

// MARK: - Get Battery Status
struct GetBatteryStatusTool: ClaudeTool {
    let name = "get_battery_status"
    let description = "Get current battery level and charging state"
    let category = ToolCategory.uiKit

    let parameters: [ToolParameter] = []
    let requiredParams: [String] = []

    @MainActor
    func execute(with arguments: [String: Any]) async throws -> String {
        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true

        let level = Int(device.batteryLevel * 100)
        let state = device.batteryState

        var result = "Battery Status:\n"
        result += "- Level: \(level)%\n"
        result += "- State: \(state.displayName)\n"
        result += "- Low Power Mode: \(ProcessInfo.processInfo.isLowPowerModeEnabled ? "On" : "Off")\n"

        return result
    }
}

// MARK: - Set Brightness
struct SetBrightnessTool: ClaudeTool {
    let name = "set_brightness"
    let description = "Set the screen brightness level (0.0 to 1.0)"
    let category = ToolCategory.uiKit

    let parameters = [
        ToolParameter(name: "level", type: .number, description: "Brightness level from 0.0 (darkest) to 1.0 (brightest)", isRequired: true)
    ]

    let requiredParams = ["level"]

    @MainActor
    func execute(with arguments: [String: Any]) async throws -> String {
        guard let level = arguments["level"] as? Double else {
            throw ToolError.invalidArguments("level is required (0.0 to 1.0)")
        }

        let clampedLevel = max(0, min(1, level))
        let previousLevel = UIScreen.main.brightness
        UIScreen.main.brightness = CGFloat(clampedLevel)

        return "Screen brightness set to \(Int(clampedLevel * 100))% (was \(Int(previousLevel * 100))%)."
    }
}

// MARK: - Trigger Haptic
struct TriggerHapticTool: ClaudeTool {
    let name = "trigger_haptic"
    let description = "Trigger a haptic feedback vibration on the device"
    let category = ToolCategory.uiKit

    let parameters = [
        ToolParameter(name: "type", type: .string, description: "Type of haptic feedback", enumValues: ["light", "medium", "heavy", "success", "warning", "error"], isRequired: true)
    ]

    let requiredParams = ["type"]

    @MainActor
    func execute(with arguments: [String: Any]) async throws -> String {
        guard let type = arguments["type"] as? String else {
            throw ToolError.invalidArguments("type is required")
        }

        switch type {
        case "light":
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case "medium":
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case "heavy":
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        case "success":
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case "warning":
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case "error":
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        default:
            throw ToolError.invalidArguments("Invalid haptic type: \(type)")
        }

        return "Triggered \(type) haptic feedback."
    }
}

// MARK: - Get Screen Info
struct GetScreenInfoTool: ClaudeTool {
    let name = "get_screen_info"
    let description = "Get detailed screen and display information"
    let category = ToolCategory.uiKit

    let parameters: [ToolParameter] = []
    let requiredParams: [String] = []

    @MainActor
    func execute(with arguments: [String: Any]) async throws -> String {
        let screen = UIScreen.main

        var result = "Screen Information:\n"
        result += "- Bounds: \(Int(screen.bounds.width)) x \(Int(screen.bounds.height)) points\n"
        result += "- Native Resolution: \(Int(screen.nativeBounds.width)) x \(Int(screen.nativeBounds.height)) pixels\n"
        result += "- Scale Factor: \(screen.scale)x\n"
        result += "- Native Scale: \(screen.nativeScale)x\n"
        result += "- Brightness: \(Int(screen.brightness * 100))%\n"

        let traits = screen.traitCollection
        result += "- Interface Style: \(traits.userInterfaceStyle == .dark ? "Dark" : "Light")\n"
        result += "- Display Gamut: \(traits.displayGamut == .P3 ? "P3 Wide Color" : "sRGB")\n"

        return result
    }
}

// MARK: - Battery State Extension
extension UIDevice.BatteryState {
    var displayName: String {
        switch self {
        case .unknown: return "Unknown"
        case .unplugged: return "Unplugged"
        case .charging: return "Charging"
        case .full: return "Full"
        @unknown default: return "Unknown"
        }
    }
}
