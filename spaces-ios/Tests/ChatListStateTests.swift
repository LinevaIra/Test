import XCTest
@testable import SpacesCore

final class ChatListStateTests: XCTestCase {
    private let spaceID = ProductSpace.sber.id

    private func child(_ title: String, in state: ChatListState) throws -> Conversation {
        try XCTUnwrap(state.conversations.first { $0.isChild && $0.title.hasPrefix(title) })
    }

    func testInitialHierarchyAndAbbreviations() {
        let state = ChatListState()
        XCTAssertEqual(state.visibleConversations.count, 11)
        XCTAssertEqual(state.conversations.filter { !$0.isChild && $0.isListedOnMain }.count, 8)
        XCTAssertEqual(state.unreadConversationCount, 4)
        XCTAssertEqual(state.visibleConversations.prefix(4).map(\.initials), ["СП", "ВО", "Р", "QA"])
        XCTAssertEqual(state.visibleConversations.dropFirst(4).map(\.initials), ["АС", "КП", "А", "МК", "В", "Д", "ОР"])
        XCTAssertEqual(state.conversation(spaceID)?.title, "Проект Сбер.продукт")
        XCTAssertEqual(state.conversation(spaceID)?.unreadCount, 12)
        let children = state.conversations.filter(\.isChild)
        XCTAssertEqual(children.count, 10)
        let active = children.filter { !$0.isMuted && $0.unreadCount > 0 }
        XCTAssertEqual(active.map(\.parentSpaceID), [spaceID, spaceID, spaceID])
        XCTAssertEqual(active.map(\.unreadCount), [3, 5, 4])
        XCTAssertEqual(active.map(\.kind), [.channel, .chat, .chat])
        XCTAssertEqual(children.filter(\.isMuted).count, 4)
    }

    func testSpaceContainsPublicAnnouncementsAndPrivateSections() throws {
        let space = try XCTUnwrap(ChatListState().conversation(spaceID)?.space)
        XCTAssertEqual(space.announcementChannel.title, "#general")
        XCTAssertEqual(space.announcementChannel.visibility, .public)
        XCTAssertEqual(space.announcementChannel.purpose, "Важные объявления")
        XCTAssertEqual(space.sections.map(\.title), ["Чат", "Почта", "ВКС"])
        for section in space.sections {
            XCTAssertEqual(section.channels.map(\.title), ["РО", "Разработка", "QA"])
            XCTAssertTrue(section.channels.allSatisfy { $0.visibility == .private })
        }
    }

    func testFiltersKeepParentsAndDoNotDoubleCountChildren() {
        var state = ChatListState()
        state.filter = .unread
        XCTAssertEqual(state.visibleConversations.count, 7)
        XCTAssertEqual(state.unreadConversationCount, 4)
        XCTAssertEqual(state.visibleConversations.filter { !$0.isChild }.count, 4)
        state.filter = .spaces
        XCTAssertEqual(state.visibleConversations.count, 4)
        XCTAssertTrue(state.visibleConversations.dropFirst().allSatisfy { $0.parentSpaceID == spaceID })
    }

    func testSearchFindsSpaceVisibleChildOrHiddenContext() {
        var state = ChatListState()
        state.query = "  сБеР  "
        XCTAssertEqual(state.visibleConversations.count, 4)
        for (query, expectedChildren) in [("QA", ["QA"]), ("ПОЧТА", []), ("РО", []), ("паша", ["Разработка"])] {
            state.query = query
            let block = state.visibleConversations.filter { $0.isSpace || $0.isChild }
            XCTAssertEqual(block.first?.id, spaceID, query)
            XCTAssertEqual(block.dropFirst().map(\.title), expectedChildren, query)
        }
        state.query = "объявления"
        XCTAssertEqual(state.visibleConversations.dropFirst().map(\.initials), ["ВО"])
    }

    func testSearchNeverRevealsMutedOrReadChildren() throws {
        var state = ChatListState()
        let qa = try child("QA", in: state)
        state.toggleMuted(qa.id)
        state.query = "QA"
        XCTAssertEqual(state.visibleConversations.map(\.id), [spaceID])
        state.toggleMuted(qa.id)
        state.markRead(qa.id)
        XCTAssertEqual(state.visibleConversations.map(\.id), [spaceID])
        state.query = "Сбер"
        XCTAssertEqual(state.visibleConversations.count, 3)
    }

    func testSearchMatchesSenderMessageAndRespectsFilter() {
        var state = ChatListState()
        state.query = "  фотографии  "
        XCTAssertEqual(state.visibleConversations.map(\.title), ["Мария Козлова"])
        state.filter = .unread
        XCTAssertTrue(state.visibleConversations.isEmpty)
        state.filter = .all
        state.query = "михаил"
        XCTAssertEqual(state.visibleConversations.map(\.title), ["Команда продукта"])
        state.filter = .spaces
        XCTAssertTrue(state.visibleConversations.isEmpty)
        state.filter = .all
        state.query = "несуществующий запрос 987"
        XCTAssertTrue(state.visibleConversations.isEmpty)
        state.query = ""
        XCTAssertEqual(state.visibleConversations.count, 11)
    }

    func testReadingChildHidesItAndRecalculatesParent() throws {
        var state = ChatListState()
        let general = try child("#general", in: state)
        state.markRead(general.id)
        XCTAssertEqual(state.conversation(general.id)?.unreadCount, 0)
        XCTAssertFalse(state.visibleConversations.contains { $0.id == general.id })
        XCTAssertEqual(state.conversation(spaceID)?.unreadCount, 9)
        XCTAssertEqual(state.visibleConversations.count, 10)
        XCTAssertEqual(state.unreadConversationCount, 4)
    }

    func testReadingSpaceClearsEveryChildButRetainsTheirIdentity() throws {
        var state = ChatListState()
        let ids = state.conversations.filter(\.isChild).map(\.id)
        state.toggleMuted(try child("QA", in: state).id)
        state.markRead(spaceID)
        XCTAssertTrue(ids.allSatisfy { state.conversation($0)?.unreadCount == 0 })
        state.filter = .unread
        XCTAssertEqual(state.visibleConversations.count, 3)
        XCTAssertEqual(state.unreadConversationCount, 3)
        state.filter = .spaces
        XCTAssertEqual(state.visibleConversations.map(\.id), [spaceID])
        XCTAssertEqual(state.conversation(spaceID)?.unreadCount, 0)
        XCTAssertEqual(state.conversations.filter(\.isChild).map(\.id), ids)
    }

    func testMuteChildPreservesUnreadAndReturnsOnlyIfUnread() throws {
        var state = ChatListState()
        let development = try child("Разработка", in: state)
        state.toggleMuted(development.id)
        XCTAssertFalse(state.visibleConversations.contains { $0.id == development.id })
        XCTAssertEqual(state.conversation(development.id)?.unreadCount, 5)
        XCTAssertEqual(state.conversation(spaceID)?.unreadCount, 12)
        state.toggleMuted(development.id)
        XCTAssertTrue(state.visibleConversations.contains { $0.id == development.id })
        state.markRead(development.id)
        state.toggleMuted(development.id)
        state.toggleMuted(development.id)
        XCTAssertFalse(state.visibleConversations.contains { $0.id == development.id })
        XCTAssertEqual(state.conversation(spaceID)?.unreadCount, 7)
    }

    func testMuteParentPreservesIndividualChildSettings() throws {
        var state = ChatListState()
        let qa = try child("QA", in: state)
        state.toggleMuted(qa.id)
        state.toggleMuted(spaceID)
        XCTAssertFalse(state.visibleConversations.contains(where: \.isChild))
        XCTAssertEqual(state.conversation(spaceID)?.unreadCount, 12)
        state.toggleMuted(spaceID)
        XCTAssertEqual(state.visibleConversations.filter(\.isChild).count, 2)
        XCTAssertTrue(state.conversation(qa.id)?.isMuted == true)
    }

    func testEligibilityIsAConditionAndNotALimitOfThree() {
        let extra = Conversation(title: "Новый канал", message: "Новое сообщение", time: "сейчас",
                                 initials: "НК", avatarTint: .accent, parentSpaceID: spaceID,
                                 kind: .channel, unreadCount: 2, order: 3)
        let orphan = Conversation(title: "Без родителя", message: "", time: "", initials: "БР",
                                  avatarTint: .accent, parentSpaceID: UUID(), unreadCount: 3, order: 4)
        var state = ChatListState(conversations: Conversation.samples + [extra, orphan])
        XCTAssertEqual(state.visibleConversations.filter(\.isChild).count, 4)
        XCTAssertFalse(state.visibleConversations.contains { $0.id == orphan.id })
        XCTAssertNil(state.route(for: orphan))
        XCTAssertEqual(state.conversation(spaceID)?.unreadCount, 14)
        state.toggleMuted(extra.id)
        XCTAssertEqual(state.visibleConversations.filter(\.isChild).count, 3)
        XCTAssertEqual(state.conversation(spaceID)?.unreadCount, 14)
        state.markRead(extra.id)
        state.toggleMuted(extra.id)
        XCTAssertEqual(state.visibleConversations.filter(\.isChild).count, 3)
        XCTAssertEqual(state.conversation(spaceID)?.unreadCount, 12)
    }

    func testPinMovesTheWholeBlockAndDoesNotPinChildren() throws {
        var state = ChatListState()
        let anna = try XCTUnwrap(state.conversations.first { $0.title == "Анна Смирнова" })
        let qa = try child("QA", in: state)
        state.togglePinned(anna.id)
        state.togglePinned(spaceID)
        XCTAssertEqual(state.visibleConversations.first?.id, anna.id)
        XCTAssertEqual(state.visibleConversations.dropFirst().prefix(4).map(\.initials), ["СП", "ВО", "Р", "QA"])
        let before = state.conversations
        state.togglePinned(qa.id)
        XCTAssertEqual(state.conversations, before)
        state.togglePinned(spaceID)
        XCTAssertEqual(state.visibleConversations.prefix(4).map(\.initials), ["СП", "ВО", "Р", "QA"])
    }

    func testCreatingChatTrimsNameAndUsesWholeCharacterAbbreviations() throws {
        var state = ChatListState()
        state.query = "qa"
        state.filter = .spaces
        XCTAssertTrue(state.createChat(named: "  Новая команда \n"))
        let chat = try XCTUnwrap(state.visibleConversations.dropFirst(4).first)
        XCTAssertEqual(chat.title, "Новая команда")
        XCTAssertEqual(chat.initials, "НК")
        XCTAssertEqual(chat.unreadCount, 0)
        XCTAssertFalse(chat.isChild)
        XCTAssertEqual(state.query, "")
        XCTAssertEqual(state.filter, .all)
        state.createChat(named: "Александр")
        XCTAssertEqual(state.visibleConversations.dropFirst(4).first?.initials, "А")
        state.createChat(named: "E\u{301}quipe produit")
        XCTAssertEqual(state.visibleConversations.dropFirst(4).first?.initials, "E\u{301}P")
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

    func testRestoreAndNewLaunchResetStateAndHierarchy() throws {
        var state = ChatListState()
        let original = state.conversations
        state.toggleMuted(try child("QA", in: state).id)
        state.toggleMuted(spaceID)
        state.togglePinned(spaceID)
        state.createChat(named: "Временный чат")
        state.markAllRead()
        state.filter = .unread
        XCTAssertEqual(state.unreadConversationCount, 0)
        XCTAssertTrue(state.visibleConversations.isEmpty)
        XCTAssertEqual(ChatListState().conversations, original)
        state.query = "Временный"
        state.restore()
        XCTAssertEqual(state.conversations, original)
        XCTAssertEqual(state.visibleConversations.count, 11)
        XCTAssertEqual(state.query, "")
        XCTAssertEqual(state.filter, .all)
        XCTAssertEqual(state.unreadConversationCount, 4)
    }

    func testSpaceAndChildrenHaveDistinctExactDestinationsWithoutMarkingRead() throws {
        let state = ChatListState()
        let space = try XCTUnwrap(state.conversation(spaceID))
        XCTAssertEqual(state.route(for: space), .space(spaceID))
        for conversation in state.conversations.filter(\.isChild) {
            XCTAssertEqual(state.route(for: conversation),
                           .dialogue(spaceID: spaceID, conversationID: conversation.id, kind: conversation.kind))
            var navigation = AppNavigationState()
            navigation.open(try XCTUnwrap(state.route(for: conversation)))
            XCTAssertEqual(navigation.path.count, 1) // No intermediate space destination.
            XCTAssertEqual(state.conversation(conversation.id)?.unreadCount, conversation.unreadCount)
        }
        let anna = try XCTUnwrap(state.conversations.first { $0.title == "Анна Смирнова" })
        XCTAssertEqual(state.route(for: anna), .personalDialogue(anna.id))
        XCTAssertNil(state.route(for: try XCTUnwrap(state.conversations.first { $0.title == "Команда продукта" })))
    }

    func testActivitiesReturnToTheExactSourceAndDoNotDuplicate() throws {
        let state = ChatListState()
        let qa = try child("QA", in: state)
        let sources: [AppRoute?] = [nil, .space(spaceID), state.route(for: qa)]
        for source in sources {
            var navigation = AppNavigationState()
            if let source { navigation.open(source) }
            let before = navigation.path
            navigation.openActivities()
            navigation.openActivities()
            XCTAssertEqual(navigation.path, before + [.activities])
            navigation.goBack()
            XCTAssertEqual(navigation.path, before)
            navigation.goBack()
            navigation.goBack()
            XCTAssertTrue(navigation.path.isEmpty)
        }
    }

    func testUnknownActionsAreNoOps() {
        var state = ChatListState()
        let before = state.conversations
        let unknown = UUID()
        state.markRead(unknown)
        state.toggleMuted(unknown)
        state.togglePinned(unknown)
        XCTAssertEqual(state.conversations, before)
    }
}
