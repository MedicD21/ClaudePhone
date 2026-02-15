import SwiftUI

@main
struct ClaudePhoneApp: App {
    @StateObject private var chatViewModel = ChatViewModel()
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(chatViewModel)
                .environmentObject(appState)
                .preferredColorScheme(.dark)
        }
    }
}

// MARK: - App State
class AppState: ObservableObject {
    @Published var isOnboarding: Bool
    @Published var selectedTab: AppTab = .chat

    init() {
        self.isOnboarding = !KeychainManager.shared.hasAPIKey
    }
}

enum AppTab: String, CaseIterable {
    case chat = "Chat"
    case tools = "Tools"
    case settings = "Settings"

    var icon: String {
        switch self {
        case .chat: return "bubble.left.and.bubble.right.fill"
        case .tools: return "wrench.and.screwdriver.fill"
        case .settings: return "gearshape.fill"
        }
    }
}
