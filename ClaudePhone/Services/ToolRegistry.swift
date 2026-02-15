import Foundation

// MARK: - Tool Registry
final class ToolRegistry {
    static let shared = ToolRegistry()

    private var registeredTools: [String: ClaudeTool] = [:]

    private init() {
        registerAllTools()
    }

    // MARK: - Public API
    var allTools: [ClaudeTool] {
        Array(registeredTools.values).sorted { $0.name < $1.name }
    }

    func tools(for category: ToolCategory) -> [ClaudeTool] {
        registeredTools.values
            .filter { $0.category == category }
            .sorted { $0.name < $1.name }
    }

    func tool(named name: String) -> ClaudeTool? {
        registeredTools[name]
    }

    func executeTool(name: String, arguments: [String: Any]) async throws -> String {
        guard let tool = registeredTools[name] else {
            throw ToolError.toolNotFound(name)
        }
        return try await tool.execute(with: arguments)
    }

    // MARK: - Registration
    private func register(_ tool: ClaudeTool) {
        registeredTools[tool.name] = tool
    }

    private func registerAllTools() {
        // EventKit - Calendar
        register(CreateCalendarEventTool())
        register(ListCalendarEventsTool())
        register(SearchCalendarEventsTool())
        register(DeleteCalendarEventTool())

        // EventKit - Reminders
        register(CreateReminderTool())
        register(ListRemindersTool())
        register(CompleteReminderTool())

        // Contacts
        register(SearchContactsTool())
        register(CreateContactTool())
        register(GetContactDetailsTool())

        // Location
        register(GetCurrentLocationTool())
        register(SearchNearbyPlacesTool())
        register(GetDirectionsTool())
        register(ReverseGeocodeTool())

        // Notifications
        register(SendNotificationTool())
        register(ListPendingNotificationsTool())
        register(RemoveNotificationsTool())

        // HealthKit
        register(GetStepCountTool())
        register(GetHeartRateTool())
        register(GetWorkoutsTool())
        register(LogWaterIntakeTool())
        register(GetSleepAnalysisTool())

        // Photos
        register(FetchRecentPhotosTool())
        register(SearchPhotosTool())
        register(GetPhotoDetailsTool())

        // Device / UIKit
        register(GetDeviceInfoTool())
        register(GetBatteryStatusTool())
        register(SetBrightnessTool())
        register(TriggerHapticTool())
        register(GetScreenInfoTool())

        // Media
        register(GetNowPlayingTool())
        register(PlayPauseMusicTool())
        register(SkipTrackTool())

        // Motion
        register(GetMotionDataTool())
        register(GetPedometerDataTool())

        // Network
        register(GetNetworkStatusTool())
        register(GetWiFiInfoTool())

        // NaturalLanguage
        register(AnalyzeSentimentTool())
        register(DetectLanguageTool())
        register(TokenizeTextTool())
        register(ExtractEntitesTool())

        // Speech
        register(SpeakTextTool())

        // Bluetooth
        register(ScanBluetoothDevicesTool())

        // HomeKit
        register(ListHomeAccessoriesTool())
        register(ControlAccessoryTool())

        // Vision
        register(RecognizeTextTool())
        register(ClassifyImageTool())
        register(DetectFacesTool())

        // NFC
        register(ScanNFCTagTool())

        // StoreKit
        register(GetProductInfoTool())

        // WebKit
        register(FetchWebContentTool())

        // CloudKit
        register(SaveCloudRecordTool())
        register(FetchCloudRecordsTool())

        // CoreImage
        register(ApplyFilterTool())
        register(GenerateQRCodeTool())
    }
}

// MARK: - Tool Errors
enum ToolError: LocalizedError {
    case toolNotFound(String)
    case invalidArguments(String)
    case permissionDenied(String)
    case executionFailed(String)

    var errorDescription: String? {
        switch self {
        case .toolNotFound(let name):
            return "Tool '\(name)' not found."
        case .invalidArguments(let msg):
            return "Invalid arguments: \(msg)"
        case .permissionDenied(let msg):
            return "Permission denied: \(msg)"
        case .executionFailed(let msg):
            return "Execution failed: \(msg)"
        }
    }
}
