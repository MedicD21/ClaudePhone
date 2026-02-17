import Foundation
import OSLog

// MARK: - Conversation Persistence Manager
final class ConversationPersistence {
    static let shared = ConversationPersistence()

    private let logger = Logger(subsystem: "com.claudephone.app", category: "persistence")
    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private var conversationsURL: URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("conversations.json")
    }

    private var metadataURL: URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("metadata.json")
    }

    private init() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Save Conversations
    func saveConversations(_ conversations: [Conversation]) throws {
        logger.info("💾 Saving \(conversations.count) conversations")

        do {
            let data = try encoder.encode(conversations)
            try data.write(to: conversationsURL, options: [.atomic, .completeFileProtection])

            // Save metadata separately for quick access
            let metadata = ConversationMetadata(
                count: conversations.count,
                lastSaved: Date(),
                totalMessages: conversations.reduce(0) { $0 + $1.messages.count }
            )
            let metadataData = try encoder.encode(metadata)
            try metadataData.write(to: metadataURL, options: [.atomic, .completeFileProtection])

            logger.info("✅ Conversations saved successfully")
        } catch {
            logger.error("❌ Failed to save conversations: \(error.localizedDescription)")
            throw PersistenceError.saveFailed(error)
        }
    }

    // MARK: - Load Conversations
    func loadConversations() throws -> [Conversation] {
        logger.info("📂 Loading conversations from disk")

        guard fileManager.fileExists(atPath: conversationsURL.path) else {
            logger.info("ℹ️ No saved conversations found, returning empty array")
            return []
        }

        do {
            let data = try Data(contentsOf: conversationsURL)
            let conversations = try decoder.decode([Conversation].self, from: data)
            logger.info("✅ Loaded \(conversations.count) conversations")
            return conversations
        } catch {
            logger.error("❌ Failed to load conversations: \(error.localizedDescription)")
            throw PersistenceError.loadFailed(error)
        }
    }

    // MARK: - Auto-save with Debouncing
    private var autoSaveTask: Task<Void, Never>?

    func autoSave(_ conversations: [Conversation]) {
        autoSaveTask?.cancel()
        autoSaveTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds debounce
            if !Task.isCancelled {
                try? saveConversations(conversations)
            }
        }
    }

    // MARK: - Clear All Data
    func clearAll() throws {
        logger.warning("⚠️ Clearing all conversation data")

        try? fileManager.removeItem(at: conversationsURL)
        try? fileManager.removeItem(at: metadataURL)

        logger.info("✅ All conversation data cleared")
    }

    // MARK: - Export Conversation
    func exportConversation(_ conversation: Conversation, format: ExportFormat) throws -> Data {
        switch format {
        case .json:
            return try encoder.encode(conversation)
        case .markdown:
            return exportAsMarkdown(conversation).data(using: .utf8) ?? Data()
        case .text:
            return exportAsText(conversation).data(using: .utf8) ?? Data()
        }
    }

    private func exportAsMarkdown(_ conversation: Conversation) -> String {
        var markdown = "# \(conversation.title)\n\n"
        markdown += "**Created:** \(ISO8601DateFormatter().string(from: conversation.createdAt))\n\n"
        markdown += "---\n\n"

        for message in conversation.messages where message.role != .system && message.role != .tool {
            let role = message.role == .user ? "**You**" : "**ClaudePhone**"
            markdown += "\(role): \(message.content)\n\n"

            if let toolCalls = message.toolCalls {
                for tool in toolCalls {
                    markdown += "  🔧 Used tool: `\(tool.name)`\n\n"
                }
            }
        }

        return markdown
    }

    private func exportAsText(_ conversation: Conversation) -> String {
        var text = "\(conversation.title)\n"
        text += String(repeating: "=", count: conversation.title.count) + "\n\n"

        for message in conversation.messages where message.role != .system && message.role != .tool {
            let role = message.role == .user ? "You" : "ClaudePhone"
            text += "\(role): \(message.content)\n\n"
        }

        return text
    }

    // MARK: - Get Storage Size
    func getStorageSize() -> Int64 {
        let conversationsSize = (try? fileManager.attributesOfItem(atPath: conversationsURL.path)[.size] as? Int64) ?? 0
        let metadataSize = (try? fileManager.attributesOfItem(atPath: metadataURL.path)[.size] as? Int64) ?? 0
        return conversationsSize + metadataSize
    }
}

// MARK: - Supporting Types
struct ConversationMetadata: Codable {
    let count: Int
    let lastSaved: Date
    let totalMessages: Int
}

enum ExportFormat {
    case json
    case markdown
    case text
}

enum PersistenceError: LocalizedError {
    case saveFailed(Error)
    case loadFailed(Error)

    var errorDescription: String? {
        switch self {
        case .saveFailed(let error):
            return "Failed to save conversations: \(error.localizedDescription)"
        case .loadFailed(let error):
            return "Failed to load conversations: \(error.localizedDescription)"
        }
    }
}
