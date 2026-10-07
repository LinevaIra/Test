import XCTest
@testable import SpacesCore

final class SpaceHomeStateTests: XCTestCase {
    private let space = ProductSpace.sber

    private func date(_ value: String) throws -> Date {
        try XCTUnwrap(ISO8601DateFormatter().date(from: value))
    }

    func testCompleteStructureIsVisibleRegardlessOfMainFilterQueryAndMute() {
        var state = ChatListState()
        state.query = "несуществующий запрос"
        state.filter = .unread
        state.toggleMuted(space.id)
        XCTAssertEqual(state.spaceConversations(space.id).map(\.initials), ["ВО"])
        for section in space.sections {
            let conversations = state.spaceConversations(space.id, sectionID: section.id)
            XCTAssertEqual(conversations.map(\.title), ["РО", "Разработка", "QA"])
            XCTAssertTrue(conversations.allSatisfy { $0.sectionID == section.id && $0.parentSpaceID == space.id })
            XCTAssertTrue(conversations.allSatisfy { $0.kind == (section.title == "Чат" ? .chat : .channel) })
        }
        XCTAssertEqual(state.conversations.filter { $0.parentSpaceID == space.id }.count, 10)
        XCTAssertEqual(state.conversation(space.id)?.unreadCount, 12)
        XCTAssertEqual(state.conversation(space.id)?.unreadMentionCount, 2)
    }

    func testUnreadMentionsAreIncludedNotAddedToMessageTotals() {
        let state = ChatListState()
        let chat = space.sections[0]
        XCTAssertEqual(state.sectionUnreadCount(space.id, sectionID: chat.id), 9)
        XCTAssertEqual(state.sectionMentionCount(space.id, sectionID: chat.id), 2)
        XCTAssertEqual(state.conversation(space.id)?.unreadCount, 12)
        for conversation in state.conversations {
            XCTAssertLessThanOrEqual(conversation.unreadMentionCount, conversation.unreadCount)
        }
    }

    func testMuteKeepsMentionAndReadClearsItInAllViews() throws {
        var state = ChatListState()
        let chat = space.sections[0]
        let qa = try XCTUnwrap(state.spaceConversations(space.id, sectionID: chat.id).first { $0.title == "QA" })
        state.toggleMuted(qa.id)
        XCTAssertEqual(state.conversation(qa.id)?.unreadCount, 4)
        XCTAssertEqual(state.conversation(qa.id)?.unreadMentionCount, 1)
        XCTAssertTrue(state.spaceConversations(space.id, sectionID: chat.id).contains { $0.id == qa.id })
        XCTAssertFalse(state.visibleConversations.contains { $0.id == qa.id })
        XCTAssertEqual(state.conversation(space.id)?.unreadCount, 12)
        state.markRead(qa.id)
        XCTAssertEqual(state.conversation(qa.id)?.unreadCount, 0)
        XCTAssertEqual(state.conversation(qa.id)?.unreadMentionCount, 0)
        XCTAssertEqual(state.conversation(space.id)?.unreadCount, 8)
        XCTAssertEqual(state.sectionMentionCount(space.id, sectionID: chat.id), 1)
        XCTAssertTrue(state.spaceConversations(space.id, sectionID: chat.id).contains { $0.id == qa.id })
    }

    func testReadingSpaceAndReadingAllClearEveryMention() {
        var state = ChatListState()
        state.markRead(space.id)
        XCTAssertTrue(state.conversations.filter { $0.id == space.id || $0.parentSpaceID == space.id }
            .allSatisfy { $0.unreadCount == 0 && $0.unreadMentionCount == 0 })
        state.restore()
        XCTAssertEqual(state.conversation(space.id)?.unreadMentionCount, 2)
        state.markAllRead()
        XCTAssertTrue(state.conversations.allSatisfy { $0.unreadCount == 0 && $0.unreadMentionCount == 0 })
    }

    func testSameNamedQAChannelsRouteToThreeDifferentIdentities() throws {
        let state = ChatListState()
        let qas = try space.sections.map { section in
            try XCTUnwrap(state.spaceConversations(space.id, sectionID: section.id).first { $0.title == "QA" })
        }
        XCTAssertEqual(Set(qas.map(\.id)).count, 3)
        let routes = try qas.map { try XCTUnwrap(state.route(for: $0)) }
        XCTAssertEqual(Set(routes).count, 3)
        for qa in qas {
            XCTAssertEqual(state.route(for: qa), .dialogue(spaceID: space.id, conversationID: qa.id, kind: qa.kind))
        }
        XCTAssertEqual(qas.map(\.kind), [.chat, .channel, .channel])
    }

    func testCollapseStateIsIndependentAndPreservesScrollAnchors() {
        var presentation = SpaceHomeState()
        let snapshot = ChatListState().conversations
        presentation.workScrollID = snapshot[0].id
        presentation.personalScrollID = snapshot[1].id
        presentation.combinedScrollID = snapshot[2].id
        XCTAssertTrue(space.sections.allSatisfy { presentation.isExpanded($0.id) })
        presentation.toggleSection(space.sections[0].id)
        presentation.toggleSection(space.sections[1].id)
        XCTAssertFalse(presentation.isExpanded(space.sections[0].id))
        XCTAssertFalse(presentation.isExpanded(space.sections[1].id))
        XCTAssertTrue(presentation.isExpanded(space.sections[2].id))
        presentation.toggleSection(space.sections[0].id)
        XCTAssertTrue(presentation.isExpanded(space.sections[0].id))
        XCTAssertFalse(presentation.isExpanded(space.sections[1].id))
        XCTAssertEqual(presentation.workScrollID, snapshot[0].id)
        XCTAssertEqual(presentation.personalScrollID, snapshot[1].id)
        XCTAssertEqual(presentation.combinedScrollID, snapshot[2].id)
        XCTAssertEqual(ChatListState().conversations, snapshot)
        XCTAssertTrue(SpaceHomeState().collapsedSectionIDs.isEmpty)
    }

    func testPersonalFiveUsesChronologyAndSharedIDs() {
        let state = ChatListState()
        let recent = state.recentPersonalConversations
        XCTAssertEqual(recent.map(\.title), ["Анна Смирнова", "Алексей", "Ирина Петрова", "Мария Козлова", "Дмитрий"])
        XCTAssertTrue(recent.allSatisfy { $0.isPersonal && $0.parentSpaceID == nil && !$0.isSpace })
        XCTAssertEqual(state.conversations.filter(\.isPersonal).count, 6)
        XCTAssertTrue(recent.allSatisfy { state.conversation($0.id) == $0 })
        XCTAssertFalse(recent.contains { $0.title == "Сергей Орлов" })
        // The two additional global demo DMs do not change the main fixture's eight roots.
        XCTAssertEqual(state.visibleConversations.count, 11)
        XCTAssertEqual(state.unreadConversationCount, 4)
    }

    func testPersonalFiveIgnoresQueryFilterMuteAndPin() throws {
        var state = ChatListState()
        let before = state.recentPersonalConversations.map(\.id)
        let anna = try XCTUnwrap(state.conversations.first { $0.title == "Анна Смирнова" })
        state.query = "QA"
        state.filter = .spaces
        state.toggleMuted(anna.id)
        state.togglePinned(anna.id)
        state.markRead(anna.id)
        XCTAssertEqual(state.recentPersonalConversations.map(\.id), before)
        XCTAssertEqual(state.recentPersonalConversations.first?.unreadCount, 0)
        XCTAssertTrue(state.recentPersonalConversations.first?.isMuted == true)
    }

    func testPersonalListRemainsGlobalWhenAnotherSpaceIsAdded() {
        let state = ChatListState()
        let other = ProductSpace(id: UUID(), title: "Другое пространство",
                                 announcementChannel: space.announcementChannel, sections: space.sections)
        let root = Conversation(id: other.id, title: other.title, message: "", time: "",
                                initials: "ДП", avatarTint: .accent, space: other, order: 20)
        let child = Conversation(title: "QA", message: "", time: "", initials: "QA", avatarTint: .accent,
                                 parentSpaceID: other.id, section: "Чат", sectionID: other.sections[0].id,
                                 unreadCount: 2, order: 0)
        let expanded = ChatListState(conversations: state.conversations + [root, child])
        XCTAssertEqual(expanded.recentPersonalConversations, state.recentPersonalConversations)
        XCTAssertEqual(expanded.spaceConversations(other.id, sectionID: other.sections[0].id).map(\.id), [child.id])
        XCTAssertFalse(expanded.spaceConversations(space.id, sectionID: space.sections[0].id).contains { $0.id == child.id })
    }

    func testNewerMessageReordersPersonalFiveWithoutDuplicating() throws {
        var state = ChatListState()
        let sergey = try XCTUnwrap(state.conversations.first { $0.title == "Сергей Орлов" })
        let messageAt = try date("2026-10-07T13:01:00+03:00")
        state.updateLastMessage(sergey.id, text: "Есть новый вопрос", at: messageAt)
        XCTAssertEqual(state.recentPersonalConversations.map(\.title),
                       ["Сергей Орлов", "Анна Смирнова", "Алексей", "Ирина Петрова", "Мария Козлова"])
        XCTAssertEqual(state.conversation(sergey.id)?.message, "Есть новый вопрос")
        XCTAssertEqual(state.conversation(sergey.id)?.lastMessageAt, messageAt)
        XCTAssertEqual(Set(state.recentPersonalConversations.map(\.id)).count, 5)
        state.updateLastMessage(sergey.id, text: "Старое сообщение", at: try date("2026-10-06T12:00:00+03:00"))
        XCTAssertEqual(state.conversation(sergey.id)?.message, "Есть новый вопрос")
        state.restore()
        XCTAssertFalse(state.recentPersonalConversations.contains { $0.id == sergey.id })
    }

    func testEqualDatesHaveStableOrderAndEmptyChatsDontUseOpenTime() throws {
        let at = try date("2026-10-07T10:00:00+03:00")
        let highID = UUID(uuidString: "00000000-0000-0000-0000-000000000099")!
        let lowID = UUID(uuidString: "00000000-0000-0000-0000-000000000098")!
        let first = Conversation(id: highID, title: "Первый", message: "", time: "", initials: "П", avatarTint: .accent,
                                 isPersonal: true, lastMessageAt: at, order: 0)
        let second = Conversation(id: lowID, title: "Второй", message: "", time: "", initials: "В", avatarTint: .accent,
                                  isPersonal: true, lastMessageAt: at, order: 1)
        var state = ChatListState(conversations: [first, second])
        XCTAssertEqual(state.recentPersonalConversations.map(\.id), [lowID, highID])
        state.createChat(named: "Пустой диалог")
        XCTAssertEqual(state.recentPersonalConversations.map(\.id), [lowID, highID])
        let empty = try XCTUnwrap(state.conversations.first { $0.title == "Пустой диалог" })
        state.updateLastMessage(empty.id, text: "Первое сообщение", at: at.addingTimeInterval(1))
        XCTAssertEqual(state.recentPersonalConversations.first?.id, empty.id)
    }

    func testWorkAndPersonalEmptyStatesAreIndependentAndNeverPadded() {
        let samples = ChatListState().conversations
        let onlyWork = ChatListState(conversations: samples.filter { !$0.isPersonal })
        XCTAssertTrue(onlyWork.recentPersonalConversations.isEmpty)
        XCTAssertEqual(onlyWork.spaceConversations(space.id).count, 1)
        let noWork = ChatListState(conversations: samples.filter { !$0.isChild })
        XCTAssertTrue(noWork.spaceConversations(space.id).isEmpty)
        XCTAssertEqual(noWork.recentPersonalConversations.count, 5)
        let few = ChatListState(conversations: Array(samples.filter(\.isPersonal).prefix(2)))
        XCTAssertEqual(few.recentPersonalConversations.count, 2)
        XCTAssertTrue(ChatListState(conversations: []).recentPersonalConversations.isEmpty)
        XCTAssertTrue(noWork.spaceConversations(UUID()).isEmpty)
    }

    func testPersonalDialogueHasNoSpaceRouteAndReturnsToSourceThroughActivities() throws {
        let state = ChatListState()
        let anna = try XCTUnwrap(state.recentPersonalConversations.first)
        let route = try XCTUnwrap(state.route(for: anna))
        XCTAssertEqual(route, .personalDialogue(anna.id))
        var navigation = AppNavigationState()
        navigation.open(.space(space.id))
        navigation.open(route)
        navigation.openActivities()
        navigation.goBack()
        XCTAssertEqual(navigation.path, [.space(space.id), route])
        navigation.goBack()
        XCTAssertEqual(navigation.path, [.space(space.id)])
        navigation.goBack()
        XCTAssertTrue(navigation.path.isEmpty)
        XCTAssertEqual(state.recentPersonalConversations.first?.unreadCount, 2)
    }

    func testDisplayTimeUsesMoscowDayBoundaryRatherThanUTC() throws {
        let now = try date("2026-10-07T12:00:00+03:00")
        var state = ChatListState()
        let sergey = try XCTUnwrap(state.conversations.first { $0.title == "Сергей Орлов" })
        state.updateLastMessage(sergey.id, text: "Ночное сообщение", at: try date("2026-10-06T22:30:00Z"))
        XCTAssertEqual(state.conversation(sergey.id)?.displayTime(relativeTo: now), "01:30")
        let dmitry = try XCTUnwrap(state.conversations.first { $0.title == "Дмитрий" })
        XCTAssertEqual(dmitry.displayTime(relativeTo: now), "вчера")
    }
}
