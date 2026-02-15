import Foundation
import SwiftUI
import Combine

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
    private var streamTask: Task<Void, Never>?

    init() {
        createNewConversation()
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
        conversations.removeAll { $0.id == conversation.id }
        if currentConversation?.id == conversation.id {
            currentConversation = conversations.first
            if currentConversation == nil {
                createNewConversation()
            }
        }
    }

    // MARK: - Send Message
    func sendMessage(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard var conversation = currentConversation else { return }

        // Add user message
        let userMessage = ChatMessage(role: .user, content: text)
        conversation.messages.append(userMessage)
        conversation.updatedAt = Date()

        // Auto-title from first message
        if conversation.messages.filter({ $0.role == .user }).count == 1 {
            conversation.title = String(text.prefix(40)) + (text.count > 40 ? "..." : "")
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
        guard var conversation = currentConversation else { return }

        isLoading = true
        errorMessage = nil
        streamingText = ""
        activeToolCalls = []

        // Add placeholder assistant message
        var assistantMessage = ChatMessage(role: .assistant, content: "", isStreaming: true)
        conversation.messages.append(assistantMessage)
        currentConversation = conversation

        do {
            let tools = toolRegistry.allTools
            let stream = try await apiService.sendMessage(messages: conversation.messages.dropLast().map { $0 }, tools: tools)

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
        var results: [ToolResult] = []

        for toolCall in toolCalls {
            let inputDict = toolCall.input.mapValues { $0.value }
            do {
                let result = try await toolRegistry.executeTool(name: toolCall.name, arguments: inputDict)
                results.append(ToolResult(toolUseId: toolCall.id, content: result))
            } catch {
                results.append(ToolResult(toolUseId: toolCall.id, content: "Error: \(error.localizedDescription)", isError: true))
            }
        }

        // Add tool result message
        let toolMessage = ChatMessage(role: .tool, content: "", toolResults: results)
        conversation.messages.append(toolMessage)
        currentConversation = conversation
        updateConversationInList(conversation)

        // Continue conversation with tool results
        streamingText = ""
        var assistantMessage = ChatMessage(role: .assistant, content: "", isStreaming: true)
        conversation.messages.append(assistantMessage)
        currentConversation = conversation

        do {
            let tools = toolRegistry.allTools
            let stream = try await apiService.sendMessage(messages: conversation.messages.dropLast().map { $0 }, tools: tools)

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

            // Recursive tool handling (up to 10 rounds)
            if stopReason == "tool_use" && !pendingToolCalls.isEmpty {
                let depth = conversation.messages.filter({ $0.role == .tool }).count
                if depth < 10 {
                    await handleToolCalls(pendingToolCalls, in: &conversation)
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
            return [:]
        }
        return dict.mapValues { AnyCodable($0) }
    }
}
