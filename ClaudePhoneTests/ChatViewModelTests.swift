import XCTest
@testable import ClaudePhone

@MainActor
final class ChatViewModelTests: XCTestCase {

    var viewModel: ChatViewModel!

    override func setUp() async throws {
        try await super.setUp()
        viewModel = ChatViewModel()
    }

    override func tearDown() async throws {
        viewModel = nil
        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialState() {
        XCTAssertFalse(viewModel.conversations.isEmpty, "Should have at least one conversation on init")
        XCTAssertNotNil(viewModel.currentConversation, "Should have a current conversation")
        XCTAssertFalse(viewModel.isLoading, "Should not be loading initially")
        XCTAssertNil(viewModel.errorMessage, "Should not have errors initially")
        XCTAssertEqual(viewModel.streamingText, "", "Streaming text should be empty")
        XCTAssertTrue(viewModel.activeToolCalls.isEmpty, "Should have no active tool calls")
    }

    // MARK: - Message Validation Tests

    func testSendEmptyMessage() {
        let initialMessageCount = viewModel.currentConversation?.messages.count ?? 0

        viewModel.sendMessage("   ")

        XCTAssertEqual(
            viewModel.currentConversation?.messages.count,
            initialMessageCount,
            "Should not add empty messages"
        )
    }

    func testSendWhitespaceOnlyMessage() {
        let initialMessageCount = viewModel.currentConversation?.messages.count ?? 0

        viewModel.sendMessage("\n\t  \n")

        XCTAssertEqual(
            viewModel.currentConversation?.messages.count,
            initialMessageCount,
            "Should not add whitespace-only messages"
        )
    }

    func testSendValidMessage() {
        let message = "Hello, Claude!"

        viewModel.sendMessage(message)

        XCTAssertEqual(viewModel.currentConversation?.messages.last?.content, message)
        XCTAssertEqual(viewModel.currentConversation?.messages.last?.role, .user)
    }

    func testMessageTooLong() {
        let longMessage = String(repeating: "a", count: 10001)

        viewModel.sendMessage(longMessage)

        XCTAssertNotNil(viewModel.errorMessage, "Should set error for too-long message")
        XCTAssertTrue(viewModel.errorMessage?.contains("too long") ?? false)
    }

    // MARK: - Conversation Management Tests

    func testCreateNewConversation() {
        let initialCount = viewModel.conversations.count

        viewModel.createNewConversation()

        XCTAssertEqual(viewModel.conversations.count, initialCount + 1)
        XCTAssertEqual(viewModel.currentConversation?.id, viewModel.conversations.first?.id)
    }

    func testDeleteConversation() {
        viewModel.createNewConversation()
        let conversationToDelete = viewModel.conversations[1]
        let initialCount = viewModel.conversations.count

        viewModel.deleteConversation(conversationToDelete)

        XCTAssertEqual(viewModel.conversations.count, initialCount - 1)
        XCTAssertFalse(viewModel.conversations.contains(where: { $0.id == conversationToDelete.id }))
    }

    func testDeleteCurrentConversation() {
        guard let currentConv = viewModel.currentConversation else {
            XCTFail("Should have current conversation")
            return
        }

        viewModel.createNewConversation() // Create another one
        viewModel.selectConversation(currentConv) // Select the old one
        viewModel.deleteConversation(currentConv)

        XCTAssertNotEqual(viewModel.currentConversation?.id, currentConv.id)
        XCTAssertNotNil(viewModel.currentConversation, "Should select another conversation")
    }

    func testDeleteLastConversation() {
        // Delete all but one
        while viewModel.conversations.count > 1 {
            viewModel.deleteConversation(viewModel.conversations[1])
        }

        let lastConv = viewModel.conversations[0]
        viewModel.deleteConversation(lastConv)

        XCTAssertEqual(viewModel.conversations.count, 1, "Should create new conversation when last one is deleted")
        XCTAssertNotNil(viewModel.currentConversation)
    }

    func testSelectConversation() {
        viewModel.createNewConversation()
        let targetConversation = viewModel.conversations[1]

        viewModel.selectConversation(targetConversation)

        XCTAssertEqual(viewModel.currentConversation?.id, targetConversation.id)
    }

    // MARK: - Auto-Titling Tests

    func testAutoTitleFromFirstMessage() {
        viewModel.createNewConversation()
        let message = "What's the weather like?"

        viewModel.sendMessage(message)

        XCTAssertEqual(viewModel.currentConversation?.title, message)
    }

    func testAutoTitleTruncation() {
        viewModel.createNewConversation()
        let longMessage = String(repeating: "a", count: 50)

        viewModel.sendMessage(longMessage)

        XCTAssertEqual(viewModel.currentConversation?.title, String(longMessage.prefix(40)) + "...")
    }

    func testAutoTitleOnlyFirstMessage() {
        viewModel.createNewConversation()
        let firstMessage = "First message"
        let secondMessage = "Second message"

        viewModel.sendMessage(firstMessage)
        let titleAfterFirst = viewModel.currentConversation?.title

        viewModel.sendMessage(secondMessage)
        let titleAfterSecond = viewModel.currentConversation?.title

        XCTAssertEqual(titleAfterFirst, titleAfterSecond, "Title should not change after first message")
    }

    // MARK: - Clear All Conversations Tests

    func testClearAllConversations() {
        viewModel.createNewConversation()
        viewModel.createNewConversation()
        XCTAssertGreaterThan(viewModel.conversations.count, 1)

        viewModel.clearAllConversations()

        XCTAssertEqual(viewModel.conversations.count, 1, "Should create new conversation after clearing all")
        XCTAssertNotNil(viewModel.currentConversation)
        XCTAssertTrue(viewModel.currentConversation?.messages.isEmpty ?? false)
    }

    // MARK: - Cancellation Tests

    func testCancelStreaming() {
        viewModel.isLoading = true

        viewModel.cancelStreaming()

        XCTAssertFalse(viewModel.isLoading, "Should stop loading when cancelled")
    }
}
