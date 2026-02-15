import SwiftUI

// MARK: - Settings View
struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var apiKeyText = ""
    @State private var hasAPIKey = false
    @State private var showingDeleteAlert = false
    @State private var showSaved = false
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.backgroundPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // App Info Card
                        appInfoCard

                        // API Key Section
                        apiKeySection

                        // Framework Status
                        frameworkStatusSection

                        // About Section
                        aboutSection

                        // Danger Zone
                        dangerZone
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 100)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(AppTheme.backgroundPrimary, for: .navigationBar)
            .onAppear {
                hasAPIKey = KeychainManager.shared.hasAPIKey
            }
        }
    }

    // MARK: - App Info Card
    private var appInfoCard: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppTheme.primaryGradient)
                    .frame(width: 64, height: 64)
                    .shadow(color: AppTheme.primary.opacity(0.3), radius: 10, y: 4)

                Image(systemName: "brain.head.profile")
                    .font(.system(size: 28))
                    .foregroundColor(.white)
            }

            Text("ClaudePhone")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)

            Text("v1.0.0 • claude-sonnet-4-20250514")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(AppTheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .cardStyle()
    }

    // MARK: - API Key Section
    private var apiKeySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("API Configuration", systemImage: "key.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppTheme.textPrimary)

            VStack(spacing: 12) {
                HStack {
                    Image(systemName: hasAPIKey ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(hasAPIKey ? AppTheme.success : AppTheme.error)
                    Text(hasAPIKey ? "API Key Configured" : "No API Key")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.textPrimary)
                    Spacer()
                }

                SecureField("Enter new API key...", text: $apiKeyText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.radiusSmall)
                            .fill(AppTheme.backgroundTertiary)
                    )
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                HStack(spacing: 8) {
                    Button {
                        saveAPIKey()
                    } label: {
                        HStack {
                            Image(systemName: "checkmark")
                            Text("Save Key")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: AppTheme.radiusSmall)
                                .fill(apiKeyText.isEmpty ? AppTheme.primary.opacity(0.4) : AppTheme.primary)
                        )
                    }
                    .disabled(apiKeyText.isEmpty)

                    if hasAPIKey {
                        Button {
                            showDeleteConfirm = true
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text("Remove")
                            }
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppTheme.error)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: AppTheme.radiusSmall)
                                    .fill(AppTheme.error.opacity(0.15))
                            )
                        }
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                    .fill(AppTheme.backgroundSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                    .stroke(AppTheme.glassBorder, lineWidth: 0.5)
            )

            if showSaved {
                Label("API key saved securely to Keychain", systemImage: "lock.shield.fill")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.success)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .alert("Remove API Key?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) { deleteAPIKey() }
        } message: {
            Text("This will remove your API key from the Keychain. You'll need to re-enter it to use ClaudePhone.")
        }
    }

    // MARK: - Framework Status
    private var frameworkStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Integrated Frameworks", systemImage: "cpu")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppTheme.textPrimary)

            let categories = ToolCategory.allCases
            let toolCount = ToolRegistry.shared.allTools.count

            VStack(spacing: 1) {
                HStack {
                    Text("Total Tools")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.textPrimary)
                    Spacer()
                    Text("\(toolCount)")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(AppTheme.primary)
                }
                .padding(12)
                .background(AppTheme.backgroundSecondary)

                ForEach(categories, id: \.self) { category in
                    let count = ToolRegistry.shared.tools(for: category).count
                    if count > 0 {
                        HStack(spacing: 8) {
                            Image(systemName: category.icon)
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: category.color))
                                .frame(width: 20)

                            Text(category.rawValue)
                                .font(.system(size: 13))
                                .foregroundColor(AppTheme.textSecondary)

                            Spacer()

                            Text("\(count)")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(AppTheme.textTertiary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(AppTheme.backgroundSecondary)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                    .stroke(AppTheme.glassBorder, lineWidth: 0.5)
            )
        }
    }

    // MARK: - About Section
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("About", systemImage: "info.circle")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppTheme.textPrimary)

            VStack(spacing: 0) {
                infoRow(label: "Model", value: "claude-sonnet-4-20250514")
                Divider().background(AppTheme.glassBorder)
                infoRow(label: "API Version", value: "2023-06-01")
                Divider().background(AppTheme.glassBorder)
                infoRow(label: "Platform", value: "iOS 17+")
                Divider().background(AppTheme.glassBorder)
                infoRow(label: "Streaming", value: "Enabled")
                Divider().background(AppTheme.glassBorder)
                infoRow(label: "Tool Calling", value: "Full Support")
            }
            .background(AppTheme.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                    .stroke(AppTheme.glassBorder, lineWidth: 0.5)
            )
        }
    }

    // MARK: - Danger Zone
    private var dangerZone: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Data", systemImage: "exclamationmark.triangle")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppTheme.error)

            Button {
                showingDeleteAlert = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Clear All Conversations")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppTheme.error)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                        .fill(AppTheme.error.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                        .stroke(AppTheme.error.opacity(0.3), lineWidth: 1)
                )
            }
        }
        .alert("Clear All Conversations?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                // Clear conversations would go here
            }
        }
    }

    // MARK: - Helpers
    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(AppTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(AppTheme.textTertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func saveAPIKey() {
        do {
            try KeychainManager.shared.saveAPIKey(apiKeyText.trimmingCharacters(in: .whitespacesAndNewlines))
            apiKeyText = ""
            hasAPIKey = true
            withAnimation(AppTheme.springAnimation) {
                showSaved = true
            }
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation { showSaved = false }
            }
        } catch {
            // Error handling
        }
    }

    private func deleteAPIKey() {
        try? KeychainManager.shared.deleteAPIKey()
        hasAPIKey = false
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }
}
