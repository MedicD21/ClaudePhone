import Foundation

// MARK: - Conversation Model
struct Conversation: Identifiable, Codable {
    let id: UUID
    var title: String
    var messages: [ChatMessage]
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), title: String = "New Chat", messages: [ChatMessage] = [], createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.messages = messages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Chat Message
struct ChatMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let role: MessageRole
    var content: String
    var toolCalls: [ToolCall]?
    var toolResults: [ToolResult]?
    var isStreaming: Bool
    let timestamp: Date

    init(id: UUID = UUID(), role: MessageRole, content: String, toolCalls: [ToolCall]? = nil, toolResults: [ToolResult]? = nil, isStreaming: Bool = false, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.toolCalls = toolCalls
        self.toolResults = toolResults
        self.isStreaming = isStreaming
        self.timestamp = timestamp
    }

    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id && lhs.content == rhs.content && lhs.isStreaming == rhs.isStreaming
    }
}

// MARK: - Message Role
enum MessageRole: String, Codable {
    case user
    case assistant
    case system
    case tool
}

// MARK: - Tool Call
struct ToolCall: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let input: [String: AnyCodable]

    static func == (lhs: ToolCall, rhs: ToolCall) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name
    }
}

// MARK: - Tool Result
struct ToolResult: Identifiable, Codable, Equatable {
    let id: String
    let toolUseId: String
    let content: String
    let isError: Bool

    init(id: String = UUID().uuidString, toolUseId: String, content: String, isError: Bool = false) {
        self.id = id
        self.toolUseId = toolUseId
        self.content = content
        self.isError = isError
    }

    static func == (lhs: ToolResult, rhs: ToolResult) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - AnyCodable wrapper for dynamic JSON
struct AnyCodable: Codable, Equatable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported type")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }

    // FIXED: Proper type-aware equality instead of string comparison
    static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        switch (lhs.value, rhs.value) {
        case (is NSNull, is NSNull):
            return true
        case (let lBool as Bool, let rBool as Bool):
            return lBool == rBool
        case (let lInt as Int, let rInt as Int):
            return lInt == rInt
        case (let lDouble as Double, let rDouble as Double):
            return lDouble == rDouble
        case (let lString as String, let rString as String):
            return lString == rString
        case (let lArray as [Any], let rArray as [Any]):
            guard lArray.count == rArray.count else { return false }
            return zip(lArray, rArray).allSatisfy { AnyCodable($0) == AnyCodable($1) }
        case (let lDict as [String: Any], let rDict as [String: Any]):
            guard lDict.keys.sorted() == rDict.keys.sorted() else { return false }
            return lDict.allSatisfy { key, lValue in
                guard let rValue = rDict[key] else { return false }
                return AnyCodable(lValue) == AnyCodable(rValue)
            }
        default:
            return false
        }
    }

    var stringValue: String? { value as? String }
    var intValue: Int? { value as? Int }
    var doubleValue: Double? { value as? Double }
    var boolValue: Bool? { value as? Bool }
    var arrayValue: [Any]? { value as? [Any] }
    var dictValue: [String: Any]? { value as? [String: Any] }
}

// MARK: - API Request/Response Models

struct ClaudeAPIRequest: Encodable {
    let model: String
    let max_tokens: Int
    let system: String?
    let messages: [APIMessage]
    let tools: [APITool]?
    let stream: Bool

    struct APIMessage: Encodable {
        let role: String
        let content: APIMessageContent
    }

    enum APIMessageContent: Encodable {
        case text(String)
        case blocks([ContentBlock])

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .text(let text):
                try container.encode(text)
            case .blocks(let blocks):
                try container.encode(blocks)
            }
        }
    }

    struct ContentBlock: Encodable {
        let type: String
        let text: String?
        let id: String?
        let name: String?
        let input: [String: AnyCodable]?
        let tool_use_id: String?
        let content: String?
    }

    struct APITool: Encodable {
        let name: String
        let description: String
        let input_schema: InputSchema
    }

    struct InputSchema: Encodable {
        let type: String
        let properties: [String: PropertySchema]
        let required: [String]

        init(type: String = "object", properties: [String: PropertySchema], required: [String]) {
            self.type = type
            self.properties = properties
            self.required = required
        }
    }

    struct PropertySchema: Encodable {
        let type: String
        let description: String
        let `enum`: [String]?

        init(type: String, description: String, enumValues: [String]? = nil) {
            self.type = type
            self.description = description
            self.enum = enumValues
        }
    }
}

// MARK: - Streaming Response Events
enum StreamEvent {
    case messageStart(messageId: String)
    case contentBlockStart(index: Int, contentBlock: StreamContentBlock)
    case contentBlockDelta(index: Int, delta: StreamDelta)
    case contentBlockStop(index: Int)
    case messageDelta(stopReason: String?)
    case messageStop
    case ping
    case error(String)
}

struct StreamContentBlock: Decodable {
    let type: String
    let id: String?
    let name: String?
    let text: String?
}

struct StreamDelta: Decodable {
    let type: String
    let text: String?
    let partial_json: String?
}
