import Foundation
import SwiftUI
import Combine
import OSLog

// MARK: - Chat View Model
@MainActor
class ChatViewModel: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var currentConversation: Conversation?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var streamingText = ""
    @Published var activeToolCalls: [ToolCall] = []

    private let apiService = ClaudeAPIService.shared
    private let toolRegistry = ToolRegistry.shared
    private let persistence = ConversationPersistence.shared
    private let preferences = UserPreferences.shared
    private let logger = Logger(subsystem: "com.claudephone.app", category: "viewmodel")

    private var streamTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    // Constants
    private let maxMessageLength = 10000
    private let maxToolCallDepth = 10

    init() {
        loadConversations()
        setupAutoSave()
    }

    deinit {
        streamTask?.cancel()
        logger.info("🧹 ChatViewModel deallocated")
    }

    // MARK: - Persistence
    private func loadConversations() {
        logger.info("📂 Loading conversations from persistence")
        do {
            conversations = try persistence.loadConversations()
            if conversations.isEmpty {
                createNewConversation()
            } else {
                currentConversation = conversations.first
            }
            logger.info("✅ Loaded \(self.conversations.count) conversations")
        } catch {
            logger.error("❌ Failed to load conversations: \(error.localizedDescription)")
            createNewConversation()
        }
    }

    private func setupAutoSave() {
        // Auto-save conversations whenever they change
        $conversations
            .dropFirst() // Skip initial value
            .debounce(for: .seconds(2), scheduler: DispatchQueue.main)
            .sink { [weak self] conversations in
                self?.logger.debug("💾 Auto-saving conversations")
                self?.persistence.autoSave(conversations)
            }
            .store(in: &cancellables)
    }

    func saveConversationsNow() {
        do {
            try persistence.saveConversations(conversations)
            logger.info("✅ Conversations saved successfully")
        } catch {
            logger.error("❌ Failed to save: \(error.localizedDescription)")
            errorMessage = "Failed to save conversations: \(error.localizedDescription)"
        }
    }

    // MARK: - Conversation Management
    func createNewConversation() {
        let conversation = Conversation()
        conversations.insert(conversation, at: 0)
        currentConversation = conversation
    }

    func selectConversation(_ conversation: Conversation) {
        currentConversation = conversation
    }

    func deleteConversation(_ conversation: Conversation) {
        logger.info("🗑️ Deleting conversation: \(conversation.title)")
        conversations.removeAll { $0.id == conversation.id }
        if currentConversation?.id == conversation.id {
            currentConversation = conversations.first
            if currentConversation == nil {
                createNewConversation()
            }
        }
    }

    func clearAllConversations() {
        logger.warning("⚠️ Clearing all conversations")
        conversations.removeAll()
        do {
            try persistence.clearAll()
            createNewConversation()
            logger.info("✅ All conversations cleared")
        } catch {
            logger.error("❌ Failed to clear conversations: \(error.localizedDescription)")
            errorMessage = "Failed to clear conversations: \(error.localizedDescription)"
        }
    }

    func exportConversation(_ conversation: Conversation, format: ExportFormat) -> Data? {
        logger.info("📤 Exporting conversation: \(conversation.title)")
        do {
            return try persistence.exportConversation(conversation, format: format)
        } catch {
            logger.error("❌ Failed to export: \(error.localizedDescription)")
            errorMessage = "Failed to export conversation: \(error.localizedDescription)"
            return nil
        }
    }

    // MARK: - Send Message
    func sendMessage(_ text: String) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Input validation
        guard !trimmedText.isEmpty else {
            logger.warning("⚠️ Attempted to send empty message")
            return
        }

        guard trimmedText.count <= maxMessageLength else {
            logger.warning("⚠️ Message too long: \(trimmedText.count) characters")
            errorMessage = "Message too long. Maximum length is \(maxMessageLength) characters."
            return
        }

        guard var conversation = currentConversation else {
            logger.error("❌ No current conversation")
            return
        }

        logger.info("📤 Sending user message (\(trimmedText.count) characters)")

        // Add user message
        let userMessage = ChatMessage(role: .user, content: trimmedText)
        conversation.messages.append(userMessage)
        conversation.updatedAt = Date()

        // Auto-title from first message
        if conversation.messages.filter({ $0.role == .user }).count == 1 {
            conversation.title = String(trimmedText.prefix(40)) + (trimmedText.count > 40 ? "..." : "")
        }

        currentConversation = conversation
        updateConversationInList(conversation)

        // Start assistant response
        streamTask?.cancel()
        streamTask = Task {
            await generateResponse()
        }
    }

    // MARK: - Generate Response (Streaming with Tool Loop)
    private func generateResponse() async {
        guard var conversation = currentConversation else {
            logger.error("❌ No conversation for response generation")
            return
        }

        logger.info("🤖 Starting response generation")

        isLoading = true
        errorMessage = nil
        streamingText = "" // FIXED: Always reset streaming text
        activeToolCalls = []

        // Add placeholder assistant message
        var assistantMessage = ChatMessage(role: .assistant, content: "", isStreaming: true)
        let assistantMessageId = assistantMessage.id // Track message ID
        conversation.messages.append(assistantMessage)
        currentConversation = conversation

        do {
            // FIXED: Use only enabled tools from preferences
            let tools = preferences.getEnabledToolsForAPI()
            logger.debug("🔧 Using \(tools.count) enabled tools")

            // FIXED: Send all messages except the placeholder we just added
            let messagesToSend = conversation.messages.filter { $0.id != assistantMessageId }
            let stream = try await apiService.sendMessage(messages: messagesToSend, tools: tools)

            var currentToolId: String?
            var currentToolName: String?
            var currentToolJsonAccumulator = ""
            var pendingToolCalls: [ToolCall] = []
            var stopReason: String?

            for try await event in stream {
                if Task.isCancelled { break }

                switch event {
                case .messageStart:
                    break

                case .contentBlockStart(_, let block):
                    if block.type == "tool_use" {
                        currentToolId = block.id
                        currentToolName = block.name
                        currentToolJsonAccumulator = ""
                    }

                case .contentBlockDelta(_, let delta):
                    if delta.type == "text_delta", let text = delta.text {
                        streamingText += text
                        assistantMessage.content = streamingText
                        updateLastMessage(assistantMessage, in: &conversation)
                    } else if delta.type == "input_json_delta", let json = delta.partial_json {
                        currentToolJsonAccumulator += json
                    }

                case .contentBlockStop:
                    if let toolId = currentToolId, let toolName = currentToolName {
                        let input = parseToolInput(currentToolJsonAccumulator)
                        let toolCall = ToolCall(id: toolId, name: toolName, input: input)
                        pendingToolCalls.append(toolCall)
                        activeToolCalls = pendingToolCalls
                        currentToolId = nil
                        currentToolName = nil
                        currentToolJsonAccumulator = ""
                    }

                case .messageDelta(let reason):
                    stopReason = reason

                case .messageStop:
                    break

                case .ping:
                    break

                case .error(let msg):
                    errorMessage = msg
                }
            }

            // Finalize assistant message
            assistantMessage.isStreaming = false
            if !pendingToolCalls.isEmpty {
                assistantMessage.toolCalls = pendingToolCalls
            }
            updateLastMessage(assistantMessage, in: &conversation)

            // Handle tool calls
            if stopReason == "tool_use" && !pendingToolCalls.isEmpty {
                await handleToolCalls(pendingToolCalls, in: &conversation)
            }

        } catch {
            if !Task.isCancelled {
                errorMessage = error.localizedDescription
                assistantMessage.content = "Error: \(error.localizedDescription)"
                assistantMessage.isStreaming = false
                updateLastMessage(assistantMessage, in: &conversation)
            }
        }

        isLoading = false
        activeToolCalls = []
        currentConversation = conversation
        updateConversationInList(conversation)
    }

    // MARK: - Handle Tool Calls
    private func handleToolCalls(_ toolCalls: [ToolCall], in conversation: inout Conversation) async {
        logger.info("🔧 Handling \(toolCalls.count) tool call(s)")

        // FIXED: Check depth limit before executing
        let currentDepth = conversation.messages.filter({ $0.role == .tool }).count
        if currentDepth >= maxToolCallDepth {
            logger.warning("⚠️ Maximum tool call depth (\(self.maxToolCallDepth)) reached")
            errorMessage = "Maximum tool call depth (\(maxToolCallDepth)) reached. Please start a new conversation if you need to continue."
            return
        }

        var results: [ToolResult] = []

        for toolCall in toolCalls {
            logger.debug("🔧 Executing tool: \(toolCall.name)")
            let inputDict = toolCall.input.mapValues { $0.value }
            do {
                let result = try await toolRegistry.executeTool(name: toolCall.name, arguments: inputDict)
                results.append(ToolResult(toolUseId: toolCall.id, content: result))
                logger.debug("✅ Tool \(toolCall.name) completed successfully")
            } catch {
                logger.error("❌ Tool \(toolCall.name) failed: \(error.localizedDescription)")
                results.append(ToolResult(toolUseId: toolCall.id, content: "Error: \(error.localizedDescription)", isError: true))
            }
        }

        // Add tool result message
        let toolMessage = ChatMessage(role: .tool, content: "", toolResults: results)
        conversation.messages.append(toolMessage)
        currentConversation = conversation
        updateConversationInList(conversation)

        // Continue conversation with tool results
        streamingText = "" // FIXED: Always reset streaming text before new response
        var assistantMessage = ChatMessage(role: .assistant, content: "", isStreaming: true)
        let assistantMessageId = assistantMessage.id
        conversation.messages.append(assistantMessage)
        currentConversation = conversation

        do {
            // Use only enabled tools from preferences
            let tools = preferences.getEnabledToolsForAPI()

            // FIXED: Send all messages except the placeholder
            let messagesToSend = conversation.messages.filter { $0.id != assistantMessageId }
            let stream = try await apiService.sendMessage(messages: messagesToSend, tools: tools)

            var pendingToolCalls: [ToolCall] = []
            var currentToolId: String?
            var currentToolName: String?
            var currentToolJsonAccumulator = ""
            var stopReason: String?

            for try await event in stream {
                if Task.isCancelled { break }

                switch event {
                case .contentBlockStart(_, let block):
                    if block.type == "tool_use" {
                        currentToolId = block.id
                        currentToolName = block.name
                        currentToolJsonAccumulator = ""
                    }

                case .contentBlockDelta(_, let delta):
                    if delta.type == "text_delta", let text = delta.text {
                        streamingText += text
                        assistantMessage.content = streamingText
                        updateLastMessage(assistantMessage, in: &conversation)
                    } else if delta.type == "input_json_delta", let json = delta.partial_json {
                        currentToolJsonAccumulator += json
                    }

                case .contentBlockStop:
                    if let toolId = currentToolId, let toolName = currentToolName {
                        let input = parseToolInput(currentToolJsonAccumulator)
                        let toolCall = ToolCall(id: toolId, name: toolName, input: input)
                        pendingToolCalls.append(toolCall)
                        activeToolCalls = pendingToolCalls
                        currentToolId = nil
                        currentToolName = nil
                        currentToolJsonAccumulator = ""
                    }

                case .messageDelta(let reason):
                    stopReason = reason

                default:
                    break
                }
            }

            assistantMessage.isStreaming = false
            if !pendingToolCalls.isEmpty {
                assistantMessage.toolCalls = pendingToolCalls
            }
            updateLastMessage(assistantMessage, in: &conversation)

            // FIXED: Recursive tool handling with depth check and feedback
            if stopReason == "tool_use" && !pendingToolCalls.isEmpty {
                let depth = conversation.messages.filter({ $0.role == .tool }).count
                if depth < maxToolCallDepth {
                    logger.info("🔁 Continuing tool loop (depth: \(depth)/\(self.maxToolCallDepth))")
                    await handleToolCalls(pendingToolCalls, in: &conversation)
                } else {
                    logger.warning("⚠️ Tool call depth limit reached during recursive handling")
                    errorMessage = "Maximum tool call depth (\(maxToolCallDepth)) reached. Please start a new conversation."
                }
            }

        } catch {
            if !Task.isCancelled {
                assistantMessage.content += "\n\nError: \(error.localizedDescription)"
                assistantMessage.isStreaming = false
                updateLastMessage(assistantMessage, in: &conversation)
            }
        }
    }

    // MARK: - Cancel
    func cancelStreaming() {
        streamTask?.cancel()
        isLoading = false
    }

    // MARK: - Helpers
    private func updateLastMessage(_ message: ChatMessage, in conversation: inout Conversation) {
        if let lastIndex = conversation.messages.indices.last {
            conversation.messages[lastIndex] = message
        }
        currentConversation = conversation
    }

    private func updateConversationInList(_ conversation: Conversation) {
        if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
            conversations[index] = conversation
        }
    }

    private func parseToolInput(_ json: String) -> [String: AnyCodable] {
        guard let data = json.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            // FIXED: Log error instead of silent failure
            logger.error("❌ Failed to parse tool input JSON: \(json)")
            return [:]
        }
        return dict.mapValues { AnyCodable($0) }
    }
}
