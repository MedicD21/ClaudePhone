import Foundation

// MARK: - Claude API Service with Streaming & Tool Calling
actor ClaudeAPIService {
    static let shared = ClaudeAPIService()

    private let baseURL = "https://api.anthropic.com/v1/messages"
    private let model = "claude-sonnet-4-20250514"
    private let maxTokens = 4096
    private let apiVersion = "2023-06-01"

    private var apiKey: String? {
        KeychainManager.shared.getAPIKey()
    }

    // MARK: - System Prompt
    private let systemPrompt = """
    You are ClaudePhone, a powerful AI assistant running as a native iOS app. You have access to extensive iOS framework integrations through function tools.

    You can help users with:
    - Calendar events and reminders (EventKit)
    - Health and fitness data (HealthKit)
    - Contacts management (Contacts framework)
    - Sending messages and emails (MessageUI)
    - Notifications (UserNotifications)
    - Location services and maps (CoreLocation, MapKit)
    - Smart home control (HomeKit)
    - Music and media playback (MediaPlayer, AVFoundation)
    - Photo library management (PhotoKit)
    - Device sensors (CoreMotion, CoreBluetooth, CoreNFC)
    - Image analysis and text recognition (Vision, CoreImage)
    - Natural language processing (NaturalLanguage)
    - Speech recognition and synthesis (Speech, AVSpeechSynthesizer)
    - Augmented reality (ARKit)
    - And many more iOS capabilities

    When a user asks you to do something that requires an iOS capability, use the appropriate tool. Explain what you're doing and present results clearly. Be conversational and helpful.

    Use the dark theme color scheme: primary blue (#579cc3), accent orange (#f2a047), success green (#7fb069).
    """

    // MARK: - Send Message (Streaming)
    func sendMessage(messages: [ChatMessage], tools: [ClaudeTool]) async throws -> AsyncThrowingStream<StreamEvent, Error> {
        guard let apiKey = apiKey else {
            throw APIError.noAPIKey
        }

        let apiMessages = buildAPIMessages(from: messages)
        let apiTools = tools.map { $0.toAPITool() }

        let request = ClaudeAPIRequest(
            model: model,
            max_tokens: maxTokens,
            system: systemPrompt,
            messages: apiMessages,
            tools: apiTools.isEmpty ? nil : apiTools,
            stream: true
        )

        var urlRequest = URLRequest(url: URL(string: baseURL)!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")

        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)

        let (bytes, response) = try await URLSession.shared.bytes(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            var errorBody = ""
            for try await line in bytes.lines {
                errorBody += line
            }
            throw APIError.httpError(statusCode: httpResponse.statusCode, body: errorBody)
        }

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await line in bytes.lines {
                        if line.hasPrefix("data: ") {
                            let jsonStr = String(line.dropFirst(6))
                            if let event = self.parseStreamEvent(jsonStr) {
                                continuation.yield(event)
                                if case .messageStop = event {
                                    continuation.finish()
                                    return
                                }
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Send Message (Non-Streaming)
    func sendMessageSync(messages: [ChatMessage], tools: [ClaudeTool]) async throws -> (String, [ToolCall]?, String?) {
        guard let apiKey = apiKey else {
            throw APIError.noAPIKey
        }

        let apiMessages = buildAPIMessages(from: messages)
        let apiTools = tools.map { $0.toAPITool() }

        let request = ClaudeAPIRequest(
            model: model,
            max_tokens: maxTokens,
            system: systemPrompt,
            messages: apiMessages,
            tools: apiTools.isEmpty ? nil : apiTools,
            stream: false
        )

        var urlRequest = URLRequest(url: URL(string: baseURL)!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")

        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.httpError(statusCode: httpResponse.statusCode, body: errorBody)
        }

        return try parseResponse(data)
    }

    // MARK: - Build API Messages
    private func buildAPIMessages(from messages: [ChatMessage]) -> [ClaudeAPIRequest.APIMessage] {
        var apiMessages: [ClaudeAPIRequest.APIMessage] = []

        for message in messages where message.role != .system {
            switch message.role {
            case .user:
                apiMessages.append(ClaudeAPIRequest.APIMessage(
                    role: "user",
                    content: .text(message.content)
                ))

            case .assistant:
                if let toolCalls = message.toolCalls, !toolCalls.isEmpty {
                    var blocks: [ClaudeAPIRequest.ContentBlock] = []
                    if !message.content.isEmpty {
                        blocks.append(ClaudeAPIRequest.ContentBlock(
                            type: "text", text: message.content,
                            id: nil, name: nil, input: nil, tool_use_id: nil, content: nil
                        ))
                    }
                    for tc in toolCalls {
                        blocks.append(ClaudeAPIRequest.ContentBlock(
                            type: "tool_use", text: nil,
                            id: tc.id, name: tc.name, input: tc.input,
                            tool_use_id: nil, content: nil
                        ))
                    }
                    apiMessages.append(ClaudeAPIRequest.APIMessage(
                        role: "assistant",
                        content: .blocks(blocks)
                    ))
                } else {
                    apiMessages.append(ClaudeAPIRequest.APIMessage(
                        role: "assistant",
                        content: .text(message.content)
                    ))
                }

            case .tool:
                if let results = message.toolResults {
                    var blocks: [ClaudeAPIRequest.ContentBlock] = []
                    for result in results {
                        blocks.append(ClaudeAPIRequest.ContentBlock(
                            type: "tool_result", text: nil,
                            id: nil, name: nil, input: nil,
                            tool_use_id: result.toolUseId,
                            content: result.content
                        ))
                    }
                    apiMessages.append(ClaudeAPIRequest.APIMessage(
                        role: "user",
                        content: .blocks(blocks)
                    ))
                }

            case .system:
                break
            }
        }

        return apiMessages
    }

    // MARK: - Parse Stream Event
    private func parseStreamEvent(_ json: String) -> StreamEvent? {
        guard let data = json.data(using: .utf8) else { return nil }

        do {
            if let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                guard let type = dict["type"] as? String else { return nil }

                switch type {
                case "message_start":
                    let messageId = (dict["message"] as? [String: Any])?["id"] as? String ?? ""
                    return .messageStart(messageId: messageId)

                case "content_block_start":
                    let index = dict["index"] as? Int ?? 0
                    if let cb = dict["content_block"] as? [String: Any] {
                        let block = StreamContentBlock(
                            type: cb["type"] as? String ?? "",
                            id: cb["id"] as? String,
                            name: cb["name"] as? String,
                            text: cb["text"] as? String
                        )
                        return .contentBlockStart(index: index, contentBlock: block)
                    }
                    return nil

                case "content_block_delta":
                    let index = dict["index"] as? Int ?? 0
                    if let d = dict["delta"] as? [String: Any] {
                        let delta = StreamDelta(
                            type: d["type"] as? String ?? "",
                            text: d["text"] as? String,
                            partial_json: d["partial_json"] as? String
                        )
                        return .contentBlockDelta(index: index, delta: delta)
                    }
                    return nil

                case "content_block_stop":
                    let index = dict["index"] as? Int ?? 0
                    return .contentBlockStop(index: index)

                case "message_delta":
                    let delta = dict["delta"] as? [String: Any]
                    let stopReason = delta?["stop_reason"] as? String
                    return .messageDelta(stopReason: stopReason)

                case "message_stop":
                    return .messageStop

                case "ping":
                    return .ping

                case "error":
                    let errorMsg = (dict["error"] as? [String: Any])?["message"] as? String ?? "Unknown error"
                    return .error(errorMsg)

                default:
                    return nil
                }
            }
        } catch {
            return nil
        }
        return nil
    }

    // MARK: - Parse Non-Streaming Response
    private func parseResponse(_ data: Data) throws -> (String, [ToolCall]?, String?) {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.parseError
        }

        let stopReason = json["stop_reason"] as? String
        var textContent = ""
        var toolCalls: [ToolCall] = []

        if let content = json["content"] as? [[String: Any]] {
            for block in content {
                let type = block["type"] as? String
                if type == "text", let text = block["text"] as? String {
                    textContent += text
                } else if type == "tool_use" {
                    let id = block["id"] as? String ?? UUID().uuidString
                    let name = block["name"] as? String ?? ""
                    let input = block["input"] as? [String: Any] ?? [:]
                    let encodedInput = input.mapValues { AnyCodable($0) }
                    toolCalls.append(ToolCall(id: id, name: name, input: encodedInput))
                }
            }
        }

        return (textContent, toolCalls.isEmpty ? nil : toolCalls, stopReason)
    }
}

// MARK: - API Errors
enum APIError: LocalizedError {
    case noAPIKey
    case invalidResponse
    case httpError(statusCode: Int, body: String)
    case parseError
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "No API key configured. Please add your Anthropic API key in Settings."
        case .invalidResponse:
            return "Invalid response from server."
        case .httpError(let code, let body):
            return "HTTP \(code): \(body)"
        case .parseError:
            return "Failed to parse API response."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
