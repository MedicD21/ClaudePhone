import Foundation
import OSLog

// MARK: - User Preferences Manager
final class UserPreferences: ObservableObject {
    static let shared = UserPreferences()

    private let logger = Logger(subsystem: "com.claudephone.app", category: "preferences")
    private let defaults = UserDefaults.standard

    // MARK: - Keys
    private enum Keys {
        static let enabledTools = "enabledTools"
        static let requireToolConfirmation = "requireToolConfirmation"
        static let maxConversations = "maxConversations"
        static let autoSaveEnabled = "autoSaveEnabled"
        static let hapticFeedbackEnabled = "hapticFeedbackEnabled"
        static let streamingEnabled = "streamingEnabled"
    }

    // MARK: - Tool Management
    @Published var enabledTools: Set<String> {
        didSet {
            defaults.set(Array(enabledTools), forKey: Keys.enabledTools)
            logger.info("✅ Updated enabled tools: \(self.enabledTools.count) tools enabled")
        }
    }

    @Published var requireToolConfirmation: Bool {
        didSet {
            defaults.set(requireToolConfirmation, forKey: Keys.requireToolConfirmation)
        }
    }

    // MARK: - Conversation Settings
    @Published var maxConversations: Int {
        didSet {
            defaults.set(maxConversations, forKey: Keys.maxConversations)
        }
    }

    @Published var autoSaveEnabled: Bool {
        didSet {
            defaults.set(autoSaveEnabled, forKey: Keys.autoSaveEnabled)
        }
    }

    // MARK: - UI Settings
    @Published var hapticFeedbackEnabled: Bool {
        didSet {
            defaults.set(hapticFeedbackEnabled, forKey: Keys.hapticFeedbackEnabled)
        }
    }

    @Published var streamingEnabled: Bool {
        didSet {
            defaults.set(streamingEnabled, forKey: Keys.streamingEnabled)
        }
    }

    // MARK: - Initialization
    private init() {
        // Load from UserDefaults or use defaults
        let savedTools = defaults.array(forKey: Keys.enabledTools) as? [String] ?? []
        self.enabledTools = Set(savedTools.isEmpty ? ToolRegistry.shared.allTools.map(\.name) : savedTools)

        self.requireToolConfirmation = defaults.object(forKey: Keys.requireToolConfirmation) as? Bool ?? false
        self.maxConversations = defaults.object(forKey: Keys.maxConversations) as? Int ?? 50
        self.autoSaveEnabled = defaults.object(forKey: Keys.autoSaveEnabled) as? Bool ?? true
        self.hapticFeedbackEnabled = defaults.object(forKey: Keys.hapticFeedbackEnabled) as? Bool ?? true
        self.streamingEnabled = defaults.object(forKey: Keys.streamingEnabled) as? Bool ?? true

        logger.info("📋 User preferences loaded")
    }

    // MARK: - Tool Control Methods
    func isToolEnabled(_ toolName: String) -> Bool {
        return enabledTools.contains(toolName)
    }

    func enableTool(_ toolName: String) {
        enabledTools.insert(toolName)
    }

    func disableTool(_ toolName: String) {
        enabledTools.remove(toolName)
    }

    func enableAllTools() {
        enabledTools = Set(ToolRegistry.shared.allTools.map(\.name))
        logger.info("✅ All tools enabled")
    }

    func disableAllTools() {
        enabledTools.removeAll()
        logger.warning("⚠️ All tools disabled")
    }

    func enableCategory(_ category: ToolCategory) {
        let categoryTools = ToolRegistry.shared.tools(for: category).map(\.name)
        enabledTools.formUnion(categoryTools)
        logger.info("✅ Enabled all tools in category: \(category.rawValue)")
    }

    func disableCategory(_ category: ToolCategory) {
        let categoryTools = ToolRegistry.shared.tools(for: category).map(\.name)
        enabledTools.subtract(categoryTools)
        logger.info("⚠️ Disabled all tools in category: \(category.rawValue)")
    }

    // MARK: - Reset to Defaults
    func resetToDefaults() {
        logger.warning("⚠️ Resetting preferences to defaults")

        enabledTools = Set(ToolRegistry.shared.allTools.map(\.name))
        requireToolConfirmation = false
        maxConversations = 50
        autoSaveEnabled = true
        hapticFeedbackEnabled = true
        streamingEnabled = true

        logger.info("✅ Preferences reset to defaults")
    }

    // MARK: - Get Enabled Tools for API
    func getEnabledToolsForAPI() -> [ClaudeTool] {
        return ToolRegistry.shared.allTools.filter { isToolEnabled($0.name) }
    }
}
