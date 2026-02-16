import SwiftUI

// MARK: - Chat View
struct ChatView: View {
    @EnvironmentObject var chatViewModel: ChatViewModel
    @State private var messageText = ""
    @State private var showConversationList = false
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.backgroundPrimary.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Messages
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                if let conversation = chatViewModel.currentConversation {
                                    if conversation.messages.isEmpty {
                                        EmptyStateView()
                                            .padding(.top, 60)
                                    } else {
                                        ForEach(conversation.messages.filter { $0.role != .system && $0.role != .tool }) { message in
                                            MessageBubbleView(message: message)
                                                .id(message.id)
                                                .transition(.asymmetric(
                                                    insertion: .move(edge: .bottom).combined(with: .opacity),
                                                    removal: .opacity
                                                ))
                                        }
                                    }

                                    // Tool call indicators
                                    if !chatViewModel.activeToolCalls.isEmpty {
                                        ToolCallIndicatorView(toolCalls: chatViewModel.activeToolCalls)
                                            .transition(.move(edge: .bottom).combined(with: .opacity))
                                    }
                                }

                                Color.clear.frame(height: 1).id("bottom")
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .padding(.bottom, 8)
                        }
                        .scrollDismissesKeyboard(.interactively)
                        .onChange(of: chatViewModel.currentConversation?.messages.count) { _, _ in
                            withAnimation(AppTheme.quickAnimation) {
                                proxy.scrollTo("bottom", anchor: .bottom)
                            }
                        }
                        .onChange(of: chatViewModel.streamingText) { _, _ in
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }

                    // Error banner
                    if let error = chatViewModel.errorMessage {
                        ErrorBannerView(message: error) {
                            chatViewModel.errorMessage = nil
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    // Input bar
                    ChatInputBar(
                        text: $messageText,
                        isLoading: chatViewModel.isLoading,
                        isFocused: $isInputFocused,
                        onSend: {
                            let text = messageText
                            messageText = ""
                            chatViewModel.sendMessage(text)
                        },
                        onCancel: {
                            chatViewModel.cancelStreaming()
                        }
                    )
                }
            }
            .navigationTitle(chatViewModel.currentConversation?.title ?? "Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.backgroundPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showConversationList.toggle()
                    } label: {
                        Image(systemName: "sidebar.left")
                            .foregroundColor(AppTheme.primary)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        chatViewModel.createNewConversation()
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .foregroundColor(AppTheme.primary)
                    }
                }
            }
            .sheet(isPresented: $showConversationList) {
                ConversationListView()
            }
        }
    }
}

// MARK: - Empty State
struct EmptyStateView: View {
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(AppTheme.primary.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: "brain.head.profile")
                    .font(.system(size: 36))
                    .foregroundColor(AppTheme.primary)
                    .symbolEffect(.pulse, options: .repeating, value: isAnimating)
            }

            VStack(spacing: 8) {
                Text("How can I help?")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)

                Text("I can access your calendar, health data, contacts, smart home, and much more.")
                    .font(.system(size: 15))
                    .foregroundColor(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Suggestion chips
            VStack(spacing: 8) {
                SuggestionChip(text: "What's on my calendar today?", icon: "calendar")
                SuggestionChip(text: "How many steps did I take?", icon: "figure.walk")
                SuggestionChip(text: "Set a reminder for tomorrow", icon: "bell.fill")
            }
            .padding(.top, 8)
        }
        .onAppear { isAnimating = true }
    }
}

struct SuggestionChip: View {
    let text: String
    let icon: String
    @EnvironmentObject var chatViewModel: ChatViewModel

    var body: some View {
        Button {
            chatViewModel.sendMessage(text)
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.primary)

                Text(text)
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.textPrimary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .glassMorphism(cornerRadius: AppTheme.radiusRound)
        }
    }
}

// MARK: - Message Bubble
struct MessageBubbleView: View {
    let message: ChatMessage
    @State private var isVisible = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == .assistant {
                // Assistant avatar
                ZStack {
                    Circle()
                        .fill(AppTheme.primaryGradient)
                        .frame(width: 28, height: 28)

                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 13))
                        .foregroundColor(.white)
                }
                .padding(.top, 2)
            }

            if message.role == .user {
                Spacer(minLength: 48)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.system(size: 15))
                    .foregroundColor(message.role == .user ? .white : AppTheme.textPrimary)
                    .textSelection(.enabled)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                            .fill(message.role == .user ? AppTheme.primaryGradient : AnyShapeStyle(AppTheme.backgroundSecondary))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                            .stroke(message.role == .user ? Color.clear : AppTheme.glassBorder, lineWidth: 0.5)
                    )

                // Tool call badges
                if let toolCalls = message.toolCalls {
                    ForEach(toolCalls) { tc in
                        HStack(spacing: 4) {
                            Image(systemName: "wrench.fill")
                                .font(.system(size: 10))
                            Text(tc.name)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                        }
                        .foregroundColor(AppTheme.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(AppTheme.accent.opacity(0.15))
                        )
                    }
                }

                // Streaming indicator
                if message.isStreaming {
                    HStack(spacing: 4) {
                        TypingIndicator()
                    }
                }

                // Timestamp
                Text(message.timestamp, style: .time)
                    .font(.system(size: 10))
                    .foregroundColor(AppTheme.textTertiary)
            }

            if message.role == .assistant {
                Spacer(minLength: 48)
            }
        }
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 10)
        .onAppear {
            withAnimation(AppTheme.springAnimation) {
                isVisible = true
            }
        }
    }
}

// MARK: - Typing Indicator
struct TypingIndicator: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(AppTheme.primary)
                    .frame(width: 5, height: 5)
                    .scaleEffect(animating ? 1.0 : 0.5)
                    .opacity(animating ? 1.0 : 0.3)
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.15),
                        value: animating
                    )
            }
        }
        .onAppear { animating = true }
    }
}

// MARK: - Tool Call Indicator
struct ToolCallIndicatorView: View {
    let toolCalls: [ToolCall]

    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .tint(AppTheme.accent)
                .scaleEffect(0.8)

            VStack(alignment: .leading, spacing: 2) {
                Text("Running tools...")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.textPrimary)

                Text(toolCalls.map(\.name).joined(separator: ", "))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(AppTheme.accent)
            }

            Spacer()
        }
        .padding(12)
        .glassMorphism(cornerRadius: AppTheme.radiusMedium)
    }
}

// MARK: - Chat Input Bar
struct ChatInputBar: View {
    @Binding var text: String
    let isLoading: Bool
    var isFocused: FocusState<Bool>.Binding
    let onSend: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .background(AppTheme.glassBorder)

            HStack(alignment: .bottom, spacing: 8) {
                // Text field
                TextField("Message ClaudePhone...", text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .lineLimit(1...6)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                            .fill(AppTheme.backgroundTertiary)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                            .stroke(AppTheme.glassBorder, lineWidth: 0.5)
                    )
                    .focused(isFocused)

                // Send / Cancel button
                Button {
                    if isLoading {
                        onCancel()
                    } else {
                        onSend()
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(isLoading ? AppTheme.error : (text.isEmpty ? AppTheme.textTertiary.opacity(0.3) : AppTheme.primaryGradient))
                            .frame(width: 36, height: 36)

                        Image(systemName: isLoading ? "stop.fill" : "arrow.up")
                            .font(.system(size: isLoading ? 12 : 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .disabled(!isLoading && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .animation(AppTheme.quickAnimation, value: isLoading)
                .animation(AppTheme.quickAnimation, value: text.isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Rectangle()
                            .fill(AppTheme.backgroundPrimary.opacity(0.7))
                    )
            )
        }
    }
}

// MARK: - Error Banner
struct ErrorBannerView: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(AppTheme.error)

            Text(message)
                .font(.system(size: 13))
                .foregroundColor(AppTheme.textPrimary)
                .lineLimit(2)

            Spacer()

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(AppTheme.textTertiary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                .fill(AppTheme.error.opacity(0.15))
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }
}

// MARK: - Conversation List
struct ConversationListView: View {
    @EnvironmentObject var chatViewModel: ChatViewModel
    @Environment(\.dismiss) var dismiss
    @State private var conversationToDelete: Conversation?
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.backgroundPrimary.ignoresSafeArea()

                if chatViewModel.conversations.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "tray")
                            .font(.system(size: 48))
                            .foregroundColor(AppTheme.textTertiary)
                        Text("No conversations yet")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(chatViewModel.conversations) { conversation in
                                Button {
                                    chatViewModel.selectConversation(conversation)
                                    dismiss()
                                } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "bubble.left.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(
                                            conversation.id == chatViewModel.currentConversation?.id
                                            ? AppTheme.primary : AppTheme.textTertiary
                                        )

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(conversation.title)
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(AppTheme.textPrimary)
                                            .lineLimit(1)

                                        Text(conversation.updatedAt, style: .relative)
                                            .font(.system(size: 12))
                                            .foregroundColor(AppTheme.textTertiary)
                                    }

                                    Spacer()

                                    Text("\(conversation.messages.filter { $0.role == .user }.count)")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(AppTheme.textTertiary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Capsule().fill(AppTheme.backgroundTertiary))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                                        .fill(conversation.id == chatViewModel.currentConversation?.id
                                              ? AppTheme.primary.opacity(0.1) : .clear)
                                )
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    conversationToDelete = conversation
                                    showDeleteConfirm = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 8)
                }
            }
            }
            .navigationTitle("Conversations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AppTheme.primary)
                }
            }
            .confirmationDialog("Delete Conversation?", isPresented: $showDeleteConfirm, presenting: conversationToDelete) { conversation in
                Button("Delete", role: .destructive) {
                    chatViewModel.deleteConversation(conversation)
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                }
                Button("Cancel", role: .cancel) {}
            } message: { conversation in
                Text("Are you sure you want to delete '\(conversation.title)'? This action cannot be undone.")
            }
        }
    }
}
