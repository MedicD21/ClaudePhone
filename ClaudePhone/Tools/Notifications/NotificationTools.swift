import Foundation
import UserNotifications

private let notificationCenter = UNUserNotificationCenter.current()

private func requestNotificationAccess() async throws {
    let settings = await notificationCenter.notificationSettings()
    if settings.authorizationStatus == .notDetermined {
        let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
        if !granted {
            throw ToolError.permissionDenied("Notification access denied")
        }
    } else if settings.authorizationStatus == .denied {
        throw ToolError.permissionDenied("Notifications are disabled. Please enable in Settings.")
    }
}

// MARK: - Send Notification
struct SendNotificationTool: ClaudeTool {
    let name = "send_notification"
    let description = "Schedule a local notification with title, body, and optional delay"
    let category = ToolCategory.notifications

    let parameters = [
        ToolParameter(name: "title", type: .string, description: "Notification title", isRequired: true),
        ToolParameter(name: "body", type: .string, description: "Notification body text", isRequired: true),
        ToolParameter(name: "delay_seconds", type: .number, description: "Delay in seconds before showing (default 1, min 1)"),
        ToolParameter(name: "sound", type: .boolean, description: "Play notification sound (default true)"),
        ToolParameter(name: "badge", type: .integer, description: "Badge count to set on the app icon")
    ]

    let requiredParams = ["title", "body"]

    func execute(with arguments: [String: Any]) async throws -> String {
        try await requestNotificationAccess()

        guard let title = arguments["title"] as? String,
              let body = arguments["body"] as? String else {
            throw ToolError.invalidArguments("title and body are required")
        }

        let delay = max(1, arguments["delay_seconds"] as? Double ?? 1)
        let playSound = arguments["sound"] as? Bool ?? true

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        if playSound {
            content.sound = .default
        }
        if let badge = arguments["badge"] as? Int {
            content.badge = NSNumber(value: badge)
        }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        let requestId = UUID().uuidString
        let request = UNNotificationRequest(identifier: requestId, content: content, trigger: trigger)

        try await notificationCenter.add(request)

        var result = "Notification scheduled:\n"
        result += "- Title: \(title)\n"
        result += "- Body: \(body)\n"
        result += "- Delay: \(Int(delay)) seconds\n"
        result += "- ID: \(requestId)"
        return result
    }
}

// MARK: - List Pending Notifications
struct ListPendingNotificationsTool: ClaudeTool {
    let name = "list_pending_notifications"
    let description = "List all pending (scheduled but not yet delivered) notifications"
    let category = ToolCategory.notifications

    let parameters: [ToolParameter] = []
    let requiredParams: [String] = []

    func execute(with arguments: [String: Any]) async throws -> String {
        let requests = await notificationCenter.pendingNotificationRequests()

        if requests.isEmpty {
            return "No pending notifications."
        }

        var result = "Pending notifications (\(requests.count)):\n\n"
        for (i, request) in requests.enumerated() {
            result += "\(i + 1). \(request.content.title)\n"
            result += "   Body: \(request.content.body)\n"
            result += "   ID: \(request.identifier)\n"

            if let trigger = request.trigger as? UNTimeIntervalNotificationTrigger {
                result += "   Fires in: \(Int(trigger.timeInterval))s\n"
            } else if let trigger = request.trigger as? UNCalendarNotificationTrigger {
                if let nextDate = trigger.nextTriggerDate() {
                    let formatter = DateFormatter()
                    formatter.dateStyle = .short
                    formatter.timeStyle = .short
                    result += "   Next trigger: \(formatter.string(from: nextDate))\n"
                }
            }
            result += "\n"
        }

        return result
    }
}

// MARK: - Remove Notifications
struct RemoveNotificationsTool: ClaudeTool {
    let name = "remove_notifications"
    let description = "Remove pending or delivered notifications by ID, or remove all"
    let category = ToolCategory.notifications

    let parameters = [
        ToolParameter(name: "notification_ids", type: .array, description: "Array of notification IDs to remove. Omit to remove all."),
        ToolParameter(name: "remove_delivered", type: .boolean, description: "Also remove from notification center (default true)")
    ]

    let requiredParams: [String] = []

    func execute(with arguments: [String: Any]) async throws -> String {
        let removeDelivered = arguments["remove_delivered"] as? Bool ?? true

        if let ids = arguments["notification_ids"] as? [String] {
            notificationCenter.removePendingNotificationRequests(withIdentifiers: ids)
            if removeDelivered {
                notificationCenter.removeDeliveredNotifications(withIdentifiers: ids)
            }
            return "Removed \(ids.count) notification(s)."
        } else {
            notificationCenter.removeAllPendingNotificationRequests()
            if removeDelivered {
                notificationCenter.removeAllDeliveredNotifications()
            }
            return "All notifications removed."
        }
    }
}
