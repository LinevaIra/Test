import XCTest
@testable import SpacesCore

final class ChatListStateTests: XCTestCase {
    func testInitialListHasOneSpaceAndFourUnreadConversations() {
        let state = ChatListState()
        XCTAssertEqual(state.visibleConversations.count, 8)
        XCTAssertEqual(state.conversations.filter(\.isSpace).count, 1)
        XCTAssertEqual(state.unreadConversationCount, 4)
        XCTAssertEqual(state.visibleConversations.first?.title, "Проект Эфир")
        XCTAssertEqual(state.conversations.map(\.unreadCount), [12, 2, 5, 0, 0, 8, 0, 0])
    }

    func testSpaceContainsPublicAnnouncementsAndPrivateChannelsInEachSection() throws {
        let space = try XCTUnwrap(ChatListState().conversations.first?.space)
        XCTAssertEqual(space.announcementChannel.title, "#general")
        XCTAssertEqual(space.announcementChannel.visibility, .public)
        XCTAssertEqual(space.announcementChannel.purpose, "Важные объявления")
        XCTAssertEqual(space.sections.map(\.title), ["Чат", "Почта", "ВКС"])
        for section in space.sections {
            XCTAssertEqual(section.channels.map(\.title), ["РО", "Разработка", "QA"])
            XCTAssertTrue(section.channels.allSatisfy { $0.visibility == .private })
        }
    }

    func testSearchReturnsSpaceForNestedSectionsAndChannels() {
        var state = ChatListState()
        for term in ["эФиР", "ПОЧТА", "РО", "qa", "ВКС", "#general", "Разработка"] {
            state.query = term
            XCTAssertTrue(state.visibleConversations.contains { $0.title == "Проект Эфир" }, term)
            XCTAssertFalse(state.visibleConversations.contains { $0.title == "QA" }, term)
        }
    }

    func testSearchMatchesSenderAndMessageAndRespectsFilter() {
        var state = ChatListState()
        state.query = "  фотографии  "
        XCTAssertEqual(state.visibleConversations.map(\.title), ["Мария Козлова"])
        state.filter = .unread
        XCTAssertTrue(state.visibleConversations.isEmpty)
        state.filter = .all
        state.query = "михаил"
        XCTAssertEqual(state.visibleConversations.map(\.title), ["Команда продукта"])
        state.query = "несуществующий запрос 987"
        XCTAssertTrue(state.visibleConversations.isEmpty)
        state.query = ""
        XCTAssertEqual(state.visibleConversations.count, 8)
    }

    func testReadActionRemovesSpaceFromUnreadButKeepsItInSpaceFilter() throws {
        var state = ChatListState()
        let id = try XCTUnwrap(state.conversations.first?.id)
        state.markRead(id)
        state.filter = .unread
        XCTAssertEqual(state.unreadConversationCount, 3)
        XCTAssertEqual(state.visibleConversations.count, 3)
        XCTAssertFalse(state.visibleConversations.contains { $0.id == id })
        state.filter = .spaces
        XCTAssertEqual(state.visibleConversations.map(\.title), ["Проект Эфир"])
        XCTAssertEqual(state.visibleConversations.first?.unreadCount, 0)
    }

    func testPinAndMuteAreReversibleAndDoNotMarkRead() throws {
        var state = ChatListState()
        let initialOrder = state.visibleConversations.map(\.id)
        let id = try XCTUnwrap(state.conversations.first { $0.title == "Выходные" }?.id)
        state.togglePinned(id)
        XCTAssertEqual(state.visibleConversations.prefix(2).map(\.title), ["Проект Эфир", "Выходные"])
        state.toggleMuted(id)
        let chat = try XCTUnwrap(state.conversations.first { $0.id == id })
        XCTAssertFalse(chat.isMuted)
        XCTAssertEqual(chat.unreadCount, 8)
        state.togglePinned(id)
        state.toggleMuted(id)
        XCTAssertEqual(state.visibleConversations.map(\.id), initialOrder)
        XCTAssertTrue(state.conversations.first { $0.id == id }?.isMuted == true)
    }

    func testCreatingChatTrimsTitleClearsSearchAndKeepsSpacePinnedFirst() throws {
        var state = ChatListState()
        state.query = "qa"
        state.filter = .spaces
        XCTAssertTrue(state.createChat(named: "  Новый чат \n"))
        XCTAssertEqual(state.query, "")
        XCTAssertEqual(state.filter, .all)
        XCTAssertEqual(state.visibleConversations.prefix(2).map(\.title), ["Проект Эфир", "Новый чат"])
        let chat = try XCTUnwrap(state.visibleConversations.dropFirst().first)
        XCTAssertEqual(chat.message, "Пока нет сообщений")
        XCTAssertEqual(chat.initials, "НЧ")
        XCTAssertFalse(chat.isSpace)
        XCTAssertEqual(chat.unreadCount, 0)
    }

    func testWhitespaceNameIsRejectedWithoutChangingState() {
        var state = ChatListState()
        state.query = "QA"
        state.filter = .spaces
        let before = state.conversations
        XCTAssertFalse(state.createChat(named: " \n\t "))
        XCTAssertEqual(state.conversations, before)
        XCTAssertEqual(state.query, "QA")
        XCTAssertEqual(state.filter, .spaces)
    }

    func testRestoreResetsChangesAndNewStateDoesNotPersistThem() throws {
        var state = ChatListState()
        let original = state.conversations
        let id = try XCTUnwrap(original.first?.id)
        state.toggleMuted(id)
        state.togglePinned(id)
        state.createChat(named: "Временный чат")
        state.markAllRead()
        state.filter = .unread
        XCTAssertEqual(state.unreadConversationCount, 0)
        XCTAssertTrue(state.visibleConversations.isEmpty)
        XCTAssertEqual(ChatListState().conversations, original)
        state.query = "Временный"
        state.restore()
        XCTAssertEqual(state.conversations, original)
        XCTAssertEqual(state.query, "")
        XCTAssertEqual(state.filter, .all)
        XCTAssertEqual(state.unreadConversationCount, 4)
    }
}
