import Foundation
import EventKit

private func requestReminderAccess() async throws {
    if #available(iOS 17.0, *) {
        try await eventStore.requestFullAccessToReminders()
    } else {
        try await eventStore.requestAccess(to: .reminder)
    }
}

// MARK: - Create Reminder
struct CreateReminderTool: ClaudeTool {
    let name = "create_reminder"
    let description = "Create a new reminder with optional due date and priority"
    let category = ToolCategory.reminders

    let parameters = [
        ToolParameter(name: "title", type: .string, description: "Reminder title", isRequired: true),
        ToolParameter(name: "due_date", type: .string, description: "Due date in ISO 8601 or yyyy-MM-dd format"),
        ToolParameter(name: "notes", type: .string, description: "Additional notes"),
        ToolParameter(name: "priority", type: .string, description: "Priority level", enumValues: ["none", "low", "medium", "high"])
    ]

    let requiredParams = ["title"]

    func execute(with arguments: [String: Any]) async throws -> String {
        try await requestReminderAccess()

        guard let title = arguments["title"] as? String else {
            throw ToolError.invalidArguments("title is required")
        }

        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = title
        reminder.calendar = eventStore.defaultCalendarForNewReminders()

        if let dueDateStr = arguments["due_date"] as? String {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            let altFormatter = DateFormatter()
            altFormatter.dateFormat = "yyyy-MM-dd"

            if let date = formatter.date(from: dueDateStr) ?? altFormatter.date(from: dueDateStr) ?? ISO8601DateFormatter().date(from: dueDateStr) {
                let calendar = Calendar.current
                reminder.dueDateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            }
        }

        if let notes = arguments["notes"] as? String {
            reminder.notes = notes
        }

        if let priority = arguments["priority"] as? String {
            switch priority.lowercased() {
            case "high": reminder.priority = Int(EKReminderPriority.high.rawValue)
            case "medium": reminder.priority = Int(EKReminderPriority.medium.rawValue)
            case "low": reminder.priority = Int(EKReminderPriority.low.rawValue)
            default: reminder.priority = Int(EKReminderPriority.none.rawValue)
            }
        }

        try eventStore.save(reminder, commit: true)

        var result = "Reminder created successfully:\n- Title: \(title)"
        if let dc = reminder.dueDateComponents, let date = Calendar.current.date(from: dc) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            result += "\n- Due: \(displayFormatter.string(from: date))"
        }
        if let notes = reminder.notes {
            result += "\n- Notes: \(notes)"
        }
        return result
    }
}

// MARK: - List Reminders
struct ListRemindersTool: ClaudeTool {
    let name = "list_reminders"
    let description = "List reminders, optionally filtering by completion status"
    let category = ToolCategory.reminders

    let parameters = [
        ToolParameter(name: "show_completed", type: .boolean, description: "Include completed reminders (default false)"),
        ToolParameter(name: "limit", type: .integer, description: "Maximum number of reminders to return (default 20)")
    ]

    let requiredParams: [String] = []

    func execute(with arguments: [String: Any]) async throws -> String {
        try await requestReminderAccess()

        let showCompleted = arguments["show_completed"] as? Bool ?? false
        let limit = arguments["limit"] as? Int ?? 20

        let calendars = eventStore.calendars(for: .reminder)
        let predicate = eventStore.predicateForReminders(in: calendars)

        let reminders = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[EKReminder], Error>) in
            eventStore.fetchReminders(matching: predicate) { result in
                if let reminders = result {
                    continuation.resume(returning: reminders)
                } else {
                    continuation.resume(returning: [])
                }
            }
        }

        let filtered = reminders
            .filter { showCompleted || !$0.isCompleted }
            .prefix(limit)

        if filtered.isEmpty {
            return showCompleted ? "No reminders found." : "No incomplete reminders found."
        }

        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .short

        var result = "Found \(filtered.count) reminder(s):\n\n"
        for (i, reminder) in filtered.enumerated() {
            let status = reminder.isCompleted ? "[x]" : "[ ]"
            result += "\(i + 1). \(status) \(reminder.title ?? "Untitled")\n"
            if let dc = reminder.dueDateComponents, let date = Calendar.current.date(from: dc) {
                result += "   Due: \(displayFormatter.string(from: date))\n"
            }
            if let notes = reminder.notes, !notes.isEmpty {
                result += "   Notes: \(String(notes.prefix(80)))\n"
            }
            result += "\n"
        }

        return result
    }
}

// MARK: - Complete Reminder
struct CompleteReminderTool: ClaudeTool {
    let name = "complete_reminder"
    let description = "Mark a reminder as completed by searching for it by title"
    let category = ToolCategory.reminders

    let parameters = [
        ToolParameter(name: "title", type: .string, description: "Title of the reminder to complete (partial match)", isRequired: true)
    ]

    let requiredParams = ["title"]

    func execute(with arguments: [String: Any]) async throws -> String {
        try await requestReminderAccess()

        guard let title = arguments["title"] as? String else {
            throw ToolError.invalidArguments("title is required")
        }

        let calendars = eventStore.calendars(for: .reminder)
        let predicate = eventStore.predicateForReminders(in: calendars)

        let reminders = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[EKReminder], Error>) in
            eventStore.fetchReminders(matching: predicate) { result in
                continuation.resume(returning: result ?? [])
            }
        }

        guard let reminder = reminders.first(where: {
            ($0.title ?? "").localizedCaseInsensitiveContains(title) && !$0.isCompleted
        }) else {
            throw ToolError.executionFailed("No incomplete reminder found matching '\(title)'")
        }

        reminder.isCompleted = true
        reminder.completionDate = Date()
        try eventStore.save(reminder, commit: true)

        return "Reminder completed: \(reminder.title ?? title)"
    }
}
