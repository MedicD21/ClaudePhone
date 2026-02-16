import Foundation
import EventKit

// MARK: - Shared EventKit Store
let eventStore = EKEventStore()

private func requestCalendarAccess() async throws {
    if #available(iOS 17.0, *) {
        try await eventStore.requestFullAccessToEvents()
    } else {
        try await eventStore.requestAccess(to: .event)
    }
}

// MARK: - Create Calendar Event
struct CreateCalendarEventTool: ClaudeTool {
    let name = "create_calendar_event"
    let description = "Create a new calendar event with title, start/end time, location, and notes"
    let category = ToolCategory.calendar

    let parameters = [
        ToolParameter(name: "title", type: .string, description: "Event title", isRequired: true),
        ToolParameter(name: "start_date", type: .string, description: "Start date/time in ISO 8601 format (e.g. 2025-01-15T14:00:00)", isRequired: true),
        ToolParameter(name: "end_date", type: .string, description: "End date/time in ISO 8601 format", isRequired: true),
        ToolParameter(name: "location", type: .string, description: "Event location"),
        ToolParameter(name: "notes", type: .string, description: "Additional notes for the event"),
        ToolParameter(name: "all_day", type: .boolean, description: "Whether this is an all-day event")
    ]

    let requiredParams = ["title", "start_date", "end_date"]

    func execute(with arguments: [String: Any]) async throws -> String {
        try await requestCalendarAccess()

        guard let title = arguments["title"] as? String,
              let startStr = arguments["start_date"] as? String,
              let endStr = arguments["end_date"] as? String else {
            throw ToolError.invalidArguments("title, start_date, and end_date are required")
        }

        // FIXED: Try formatters in order of most common to least common
        let altFormatter = ISO8601DateFormatter()
        altFormatter.formatOptions = [.withInternetDateTime]

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"

        // Try without fractional seconds first (most common)
        guard let startDate = altFormatter.date(from: startStr)
                ?? formatter.date(from: startStr)
                ?? dateFormatter.date(from: startStr) else {
            throw ToolError.invalidArguments("Invalid start_date format. Use ISO 8601 format (e.g., 2025-01-15T14:00:00).")
        }

        guard let endDate = altFormatter.date(from: endStr)
                ?? formatter.date(from: endStr)
                ?? dateFormatter.date(from: endStr) else {
            throw ToolError.invalidArguments("Invalid end_date format. Use ISO 8601 format (e.g., 2025-01-15T15:00:00).")
        }

        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.calendar = eventStore.defaultCalendarForNewEvents
        event.isAllDay = arguments["all_day"] as? Bool ?? false

        if let location = arguments["location"] as? String {
            event.location = location
        }
        if let notes = arguments["notes"] as? String {
            event.notes = notes
        }

        try eventStore.save(event, span: .thisEvent)

        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .short

        return """
        Calendar event created successfully:
        - Title: \(title)
        - Start: \(displayFormatter.string(from: startDate))
        - End: \(displayFormatter.string(from: endDate))
        \(event.location.map { "- Location: \($0)" } ?? "")
        \(event.notes.map { "- Notes: \($0)" } ?? "")
        - Event ID: \(event.eventIdentifier ?? "unknown")
        """
    }
}

// MARK: - List Calendar Events
struct ListCalendarEventsTool: ClaudeTool {
    let name = "list_calendar_events"
    let description = "List calendar events for a specified date range. Defaults to today if no dates provided."
    let category = ToolCategory.calendar

    let parameters = [
        ToolParameter(name: "start_date", type: .string, description: "Start date in ISO 8601 or yyyy-MM-dd format. Defaults to today."),
        ToolParameter(name: "end_date", type: .string, description: "End date in ISO 8601 or yyyy-MM-dd format. Defaults to end of start date."),
        ToolParameter(name: "limit", type: .integer, description: "Maximum number of events to return (default 20)")
    ]

    let requiredParams: [String] = []

    func execute(with arguments: [String: Any]) async throws -> String {
        try await requestCalendarAccess()

        let calendar = Calendar.current
        let now = Date()

        let startDate: Date
        let endDate: Date

        if let startStr = arguments["start_date"] as? String {
            startDate = parseDate(startStr) ?? calendar.startOfDay(for: now)
        } else {
            startDate = calendar.startOfDay(for: now)
        }

        if let endStr = arguments["end_date"] as? String {
            endDate = parseDate(endStr) ?? calendar.date(byAdding: .day, value: 1, to: startDate)!
        } else {
            endDate = calendar.date(byAdding: .day, value: 1, to: startDate)!
        }

        let limit = arguments["limit"] as? Int ?? 20

        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        let events = eventStore.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
            .prefix(limit)

        if events.isEmpty {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            return "No events found between \(displayFormatter.string(from: startDate)) and \(displayFormatter.string(from: endDate))."
        }

        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .short
        displayFormatter.timeStyle = .short

        var result = "Found \(events.count) event(s):\n\n"
        for (i, event) in events.enumerated() {
            result += "\(i + 1). \(event.title ?? "Untitled")\n"
            if event.isAllDay {
                let dayFormatter = DateFormatter()
                dayFormatter.dateStyle = .medium
                result += "   All day - \(dayFormatter.string(from: event.startDate))\n"
            } else {
                result += "   \(displayFormatter.string(from: event.startDate)) - \(displayFormatter.string(from: event.endDate))\n"
            }
            if let location = event.location, !location.isEmpty {
                result += "   Location: \(location)\n"
            }
            if let notes = event.notes, !notes.isEmpty {
                result += "   Notes: \(String(notes.prefix(100)))\n"
            }
            result += "\n"
        }

        return result
    }
}

// MARK: - Search Calendar Events
struct SearchCalendarEventsTool: ClaudeTool {
    let name = "search_calendar_events"
    let description = "Search for calendar events by title within a date range"
    let category = ToolCategory.calendar

    let parameters = [
        ToolParameter(name: "query", type: .string, description: "Search query to match against event titles", isRequired: true),
        ToolParameter(name: "days_ahead", type: .integer, description: "Number of days ahead to search (default 30)")
    ]

    let requiredParams = ["query"]

    func execute(with arguments: [String: Any]) async throws -> String {
        try await requestCalendarAccess()

        guard let query = arguments["query"] as? String else {
            throw ToolError.invalidArguments("query is required")
        }

        let daysAhead = arguments["days_ahead"] as? Int ?? 30
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: Date())
        let endDate = calendar.date(byAdding: .day, value: daysAhead, to: startDate)!

        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        let events = eventStore.events(matching: predicate)
            .filter { ($0.title ?? "").localizedCaseInsensitiveContains(query) }
            .sorted { $0.startDate < $1.startDate }

        if events.isEmpty {
            return "No events found matching '\(query)' in the next \(daysAhead) days."
        }

        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .short

        var result = "Found \(events.count) event(s) matching '\(query)':\n\n"
        for (i, event) in events.enumerated() {
            result += "\(i + 1). \(event.title ?? "Untitled")\n"
            result += "   \(displayFormatter.string(from: event.startDate))\n"
            if let location = event.location, !location.isEmpty {
                result += "   Location: \(location)\n"
            }
            result += "\n"
        }

        return result
    }
}

// MARK: - Delete Calendar Event
struct DeleteCalendarEventTool: ClaudeTool {
    let name = "delete_calendar_event"
    let description = "Delete a calendar event by its event identifier"
    let category = ToolCategory.calendar

    let parameters = [
        ToolParameter(name: "event_id", type: .string, description: "The event identifier from a previous list/search", isRequired: true)
    ]

    let requiredParams = ["event_id"]

    func execute(with arguments: [String: Any]) async throws -> String {
        try await requestCalendarAccess()

        guard let eventId = arguments["event_id"] as? String else {
            throw ToolError.invalidArguments("event_id is required")
        }

        guard let event = eventStore.event(withIdentifier: eventId) else {
            throw ToolError.executionFailed("Event not found with ID: \(eventId)")
        }

        let title = event.title ?? "Untitled"
        try eventStore.remove(event, span: .thisEvent)
        return "Successfully deleted event: \(title)"
    }
}

// MARK: - Date Parsing Helper
private func parseDate(_ string: String) -> Date? {
    let formatters: [DateFormatter] = {
        let f1 = ISO8601DateFormatter()
        let f2 = DateFormatter()
        f2.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        let f3 = DateFormatter()
        f3.dateFormat = "yyyy-MM-dd"
        return [f2, f3]
    }()

    let iso = ISO8601DateFormatter()
    if let d = iso.date(from: string) { return d }

    for formatter in formatters {
        if let d = formatter.date(from: string) { return d }
    }
    return nil
}
