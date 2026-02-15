import Foundation

// MARK: - Tool Definition Protocol
protocol ClaudeTool {
    var name: String { get }
    var description: String { get }
    var parameters: [ToolParameter] { get }
    var requiredParams: [String] { get }
    var category: ToolCategory { get }

    func execute(with arguments: [String: Any]) async throws -> String
}

// MARK: - Tool Parameter
struct ToolParameter {
    let name: String
    let type: ParameterType
    let description: String
    let enumValues: [String]?
    let isRequired: Bool

    init(name: String, type: ParameterType, description: String, enumValues: [String]? = nil, isRequired: Bool = false) {
        self.name = name
        self.type = type
        self.description = description
        self.enumValues = enumValues
        self.isRequired = isRequired
    }
}

// MARK: - Parameter Types
enum ParameterType: String {
    case string
    case number
    case integer
    case boolean
    case array
    case object
}

// MARK: - Tool Category
enum ToolCategory: String, CaseIterable {
    case calendar = "Calendar"
    case reminders = "Reminders"
    case health = "Health"
    case contacts = "Contacts"
    case messages = "Messages"
    case notifications = "Notifications"
    case location = "Location"
    case homeKit = "HomeKit"
    case media = "Media"
    case photos = "Photos"
    case storeKit = "StoreKit"
    case passKit = "PassKit"
    case motion = "Motion"
    case bluetooth = "Bluetooth"
    case nfc = "NFC"
    case network = "Network"
    case vision = "Vision"
    case naturalLanguage = "NaturalLanguage"
    case speech = "Speech"
    case ar = "AR"
    case cloudKit = "CloudKit"
    case coreData = "CoreData"
    case uiKit = "UIKit"
    case webKit = "WebKit"
    case callKit = "CallKit"
    case telephony = "Telephony"
    case gameCenter = "GameCenter"
    case watchConnectivity = "WatchConnectivity"
    case nearbyInteraction = "NearbyInteraction"
    case siriKit = "SiriKit"
    case coreImage = "CoreImage"

    var icon: String {
        switch self {
        case .calendar: return "calendar"
        case .reminders: return "checklist"
        case .health: return "heart.fill"
        case .contacts: return "person.crop.circle"
        case .messages: return "message.fill"
        case .notifications: return "bell.fill"
        case .location: return "location.fill"
        case .homeKit: return "house.fill"
        case .media: return "music.note"
        case .photos: return "photo.fill"
        case .storeKit: return "cart.fill"
        case .passKit: return "wallet.pass.fill"
        case .motion: return "gyroscope"
        case .bluetooth: return "antenna.radiowaves.left.and.right"
        case .nfc: return "wave.3.right"
        case .network: return "wifi"
        case .vision: return "eye.fill"
        case .naturalLanguage: return "textformat"
        case .speech: return "waveform"
        case .ar: return "arkit"
        case .cloudKit: return "icloud.fill"
        case .coreData: return "externaldrive.fill"
        case .uiKit: return "iphone"
        case .webKit: return "globe"
        case .callKit: return "phone.fill"
        case .telephony: return "antenna.radiowaves.left.and.right.circle"
        case .gameCenter: return "gamecontroller.fill"
        case .watchConnectivity: return "applewatch"
        case .nearbyInteraction: return "point.3.connected.trianglepath.dotted"
        case .siriKit: return "mic.fill"
        case .coreImage: return "camera.filters"
        }
    }

    var color: String {
        switch self {
        case .calendar, .reminders: return "579cc3"
        case .health: return "e05555"
        case .contacts: return "579cc3"
        case .messages: return "7fb069"
        case .notifications: return "f2a047"
        case .location: return "579cc3"
        case .homeKit: return "f2a047"
        case .media: return "e05555"
        case .photos: return "7fb069"
        case .storeKit, .passKit: return "579cc3"
        case .motion: return "f2a047"
        case .bluetooth: return "579cc3"
        case .nfc: return "7fb069"
        case .network: return "579cc3"
        case .vision: return "f2a047"
        case .naturalLanguage: return "7fb069"
        case .speech: return "579cc3"
        case .ar: return "f2a047"
        case .cloudKit: return "579cc3"
        case .coreData: return "7fb069"
        case .uiKit: return "579cc3"
        case .webKit: return "f2a047"
        case .callKit: return "7fb069"
        case .telephony: return "579cc3"
        case .gameCenter: return "f2a047"
        case .watchConnectivity: return "e05555"
        case .nearbyInteraction: return "579cc3"
        case .siriKit: return "7fb069"
        case .coreImage: return "f2a047"
        }
    }
}

// MARK: - Tool to API Schema conversion
extension ClaudeTool {
    func toAPITool() -> ClaudeAPIRequest.APITool {
        var properties: [String: ClaudeAPIRequest.PropertySchema] = [:]
        for param in parameters {
            properties[param.name] = ClaudeAPIRequest.PropertySchema(
                type: param.type.rawValue,
                description: param.description,
                enumValues: param.enumValues
            )
        }

        return ClaudeAPIRequest.APITool(
            name: name,
            description: description,
            input_schema: ClaudeAPIRequest.InputSchema(
                properties: properties,
                required: requiredParams
            )
        )
    }
}
