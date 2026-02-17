import Foundation
import HomeKit

private let homeManager = HMHomeManager()

// MARK: - List Home Accessories
struct ListHomeAccessoriesTool: ClaudeTool {
    let name = "list_home_accessories"
    let description = "List all HomeKit accessories and their current states"
    let category = ToolCategory.homeKit

    let parameters: [ToolParameter] = []
    let requiredParams: [String] = []

    func execute(with arguments: [String: Any]) async throws -> String {
        // Give HomeKit time to discover homes
        try await Task.sleep(nanoseconds: 1_000_000_000)

        // FIXED: Use homes.first instead of deprecated primaryHome
        guard let home = homeManager.homes.first else {
            return "No HomeKit homes configured. Set up a home in the Home app first."
        }

        if home.accessories.isEmpty {
            return "No accessories found in '\(home.name)'. Add devices using the Home app."
        }

        var result = "Home: \(home.name)\n"
        result += "Accessories (\(home.accessories.count)):\n\n"

        for (i, accessory) in home.accessories.enumerated() {
            result += "\(i + 1). \(accessory.name)\n"
            result += "   Room: \(accessory.room?.name ?? "Unassigned")\n"
            result += "   Reachable: \(accessory.isReachable ? "Yes" : "No")\n"
            result += "   Category: \(accessory.category.localizedDescription)\n"

            for service in accessory.services where service.serviceType != HMServiceTypeAccessoryInformation {
                for characteristic in service.characteristics {
                    if let value = characteristic.value {
                        let name = characteristic.localizedDescription
                        result += "   \(name): \(value)\n"
                    }
                }
            }
            result += "\n"
        }

        if !home.rooms.isEmpty {
            result += "Rooms: \(home.rooms.map(\.name).joined(separator: ", "))\n"
        }

        return result
    }
}

// MARK: - Control Accessory
struct ControlAccessoryTool: ClaudeTool {
    let name = "control_accessory"
    let description = "Control a HomeKit accessory (e.g., turn on/off lights, set thermostat)"
    let category = ToolCategory.homeKit

    let parameters = [
        ToolParameter(name: "accessory_name", type: .string, description: "Name of the accessory to control", isRequired: true),
        ToolParameter(name: "characteristic", type: .string, description: "Characteristic to set (e.g., 'power', 'brightness', 'temperature')", isRequired: true),
        ToolParameter(name: "value", type: .string, description: "Value to set (e.g., 'true', 'false', '75', '22.5')", isRequired: true)
    ]

    let requiredParams = ["accessory_name", "characteristic", "value"]

    func execute(with arguments: [String: Any]) async throws -> String {
        guard let accessoryName = arguments["accessory_name"] as? String,
              let characteristicName = arguments["characteristic"] as? String,
              let valueStr = arguments["value"] as? String else {
            throw ToolError.invalidArguments("accessory_name, characteristic, and value are required")
        }

        try await Task.sleep(nanoseconds: 1_000_000_000)

        // FIXED: Use homes.first instead of deprecated primaryHome
        guard let home = homeManager.homes.first else {
            throw ToolError.executionFailed("No HomeKit home configured")
        }

        guard let accessory = home.accessories.first(where: {
            $0.name.localizedCaseInsensitiveContains(accessoryName)
        }) else {
            let available = home.accessories.map(\.name).joined(separator: ", ")
            throw ToolError.executionFailed("Accessory '\(accessoryName)' not found. Available: \(available)")
        }

        guard accessory.isReachable else {
            throw ToolError.executionFailed("Accessory '\(accessory.name)' is not reachable")
        }

        // Find the characteristic
        let targetType = mapCharacteristicName(characteristicName)
        var targetCharacteristic: HMCharacteristic?

        for service in accessory.services {
            for char in service.characteristics where char.characteristicType == targetType {
                targetCharacteristic = char
                break
            }
            if targetCharacteristic != nil { break }
        }

        guard let characteristic = targetCharacteristic else {
            throw ToolError.executionFailed("Characteristic '\(characteristicName)' not found on \(accessory.name)")
        }

        // Parse and set value
        let value: Any
        if valueStr.lowercased() == "true" || valueStr.lowercased() == "on" {
            value = true
        } else if valueStr.lowercased() == "false" || valueStr.lowercased() == "off" {
            value = false
        } else if let intVal = Int(valueStr) {
            value = intVal
        } else if let doubleVal = Double(valueStr) {
            value = doubleVal
        } else {
            value = valueStr
        }

        try await characteristic.writeValue(value)

        return "Set \(accessory.name) \(characteristicName) to \(valueStr)."
    }

    private func mapCharacteristicName(_ name: String) -> String {
        switch name.lowercased() {
        case "power", "on", "off": return HMCharacteristicTypePowerState
        case "brightness": return HMCharacteristicTypeBrightness
        case "hue": return HMCharacteristicTypeHue
        case "saturation": return HMCharacteristicTypeSaturation
        case "temperature", "target_temperature": return HMCharacteristicTypeTargetTemperature
        case "heating_cooling", "mode": return HMCharacteristicTypeTargetHeatingCooling
        case "lock": return HMCharacteristicTypeTargetLockMechanismState
        default: return name
        }
    }
}
