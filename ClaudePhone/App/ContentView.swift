import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var chatViewModel: ChatViewModel

    var body: some View {
        Group {
            if appState.isOnboarding {
                OnboardingView()
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                MainTabView()
                    .transition(.opacity)
            }
        }
        .animation(AppTheme.springAnimation, value: appState.isOnboarding)
    }
}

// MARK: - Main Tab View
struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @State private var tabBarVisible = true

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $appState.selectedTab) {
                ChatView()
                    .tag(AppTab.chat)

                ToolsBrowserView()
                    .tag(AppTab.tools)

                SettingsView()
                    .tag(AppTab.settings)
            }
            .tabViewStyle(.automatic)
            .tint(AppTheme.primary)

            // Custom Tab Bar
            CustomTabBar(selectedTab: $appState.selectedTab)
        }
        .ignoresSafeArea(.keyboard)
    }
}

// MARK: - Custom Tab Bar
struct CustomTabBar: View {
    @Binding var selectedTab: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                tabButton(for: tab)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(
                    Rectangle()
                        .fill(AppTheme.backgroundPrimary.opacity(0.7))
                )
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(AppTheme.glassBorder)
                        .frame(height: 0.5)
                }
        )
    }

    private func tabButton(for tab: AppTab) -> some View {
        Button {
            withAnimation(AppTheme.springAnimation) {
                selectedTab = tab
            }
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 20, weight: selectedTab == tab ? .semibold : .regular))
                    .symbolEffect(.bounce, value: selectedTab == tab)

                Text(tab.rawValue)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(selectedTab == tab ? AppTheme.primary : AppTheme.textTertiary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
    }
}

// MARK: - Onboarding View
struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var apiKey = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isAnimating = false
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        ZStack {
            AppTheme.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Logo
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.primaryGradient)
                            .frame(width: 100, height: 100)
                            .shadow(color: AppTheme.primary.opacity(0.4), radius: 20, y: 8)

                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 44))
                            .foregroundColor(.white)
                    }
                    .scaleEffect(isAnimating ? 1.0 : 0.5)
                    .opacity(isAnimating ? 1.0 : 0)

                    Text("ClaudePhone")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)

                    Text("Your AI assistant with full iOS integration")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                // API Key Input
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Anthropic API Key", systemImage: "key.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppTheme.textSecondary)

                        SecureField("sk-ant-...", text: $apiKey)
                            .textFieldStyle(.plain)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                                    .fill(AppTheme.backgroundTertiary)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                                    .stroke(isFieldFocused ? AppTheme.primary : AppTheme.glassBorder, lineWidth: 1)
                            )
                            .focused($isFieldFocused)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }

                    if showError {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.error)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    Button {
                        saveAndContinue()
                    } label: {
                        HStack {
                            Text("Get Started")
                                .font(.system(size: 17, weight: .semibold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                                .fill(apiKey.isEmpty ? AppTheme.primary.opacity(0.4) : AppTheme.primaryGradient)
                        )
                        .shadow(color: apiKey.isEmpty ? .clear : AppTheme.primary.opacity(0.3), radius: 10, y: 4)
                    }
                    .disabled(apiKey.isEmpty)
                }
                .padding(.horizontal, 24)

                Spacer()

                Text("Your API key is stored securely in the iOS Keychain")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.textTertiary)
                    .padding(.bottom, 16)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2)) {
                isAnimating = true
            }
        }
    }

    private func saveAndContinue() {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showError(message: "Please enter your API key")
            return
        }

        do {
            try KeychainManager.shared.saveAPIKey(apiKey.trimmingCharacters(in: .whitespacesAndNewlines))
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            withAnimation(AppTheme.springAnimation) {
                appState.isOnboarding = false
            }
        } catch {
            showError(message: error.localizedDescription)
        }
    }

    private func showError(message: String) {
        errorMessage = message
        withAnimation(AppTheme.springAnimation) {
            showError = true
        }
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }
}
