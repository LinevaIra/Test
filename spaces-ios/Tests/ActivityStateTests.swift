import XCTest
@testable import SpacesCore

final class ActivityStateTests: XCTestCase {
    private let space = ProductSpace.sber
    private var now: Date { ISO8601DateFormatter().date(from: "2026-10-07T13:00:00+03:00")! }

    func testEveryConversationCountComesFromSharedMessages() {
        let state = ChatListState()
        for conversation in state.conversations where !conversation.isSpace {
            let unread = state.activity.messages.filter { $0.conversationID == conversation.id && $0.isUnread }
            XCTAssertEqual(conversation.unreadCount, unread.count)
            XCTAssertEqual(conversation.unreadMentionCount, unread.filter(\.mentionsMe).count)
        }
        XCTAssertEqual(state.conversation(space.id)?.unreadCount, 12)
    }

    func testUnsubscribeOnlyRemovesDiscussionNotMentionsMessagesOrUnread() throws {
        var state = ChatListState()
        let thread = try XCTUnwrap(state.activity.subscribedDiscussions.first)
        let messages = state.activity.messages
        let mentions = state.activity.mentions
        let conversations = state.conversations
        state.activity.unsubscribe(thread.id)
        XCTAssertFalse(state.activity.subscribedDiscussions.contains { $0.id == thread.id })
        XCTAssertEqual(state.activity.messages, messages)
        XCTAssertEqual(state.activity.mentions, mentions)
        XCTAssertEqual(state.conversations, conversations)
        XCTAssertNotNil(state.activity.discussion(thread.id))
    }

    func testReadingThreadSynchronizesMentionsAndSpaceWithoutDoubleCounting() throws {
        var state = ChatListState()
        let thread = try XCTUnwrap(state.activity.subscribedDiscussions.first { $0.title == "Регресс перед релизом" })
        let mention = try XCTUnwrap(state.activity.mentions.first { $0.threadID == thread.id })
        state.readDiscussion(thread.id)
        XCTAssertTrue(state.activity.replies(thread.id).allSatisfy { !$0.isUnread })
        XCTAssertFalse(try XCTUnwrap(state.activity.message(mention.id)).isUnread)
        XCTAssertEqual(state.conversation(thread.conversationID)?.unreadCount, 0)
        XCTAssertEqual(state.conversation(space.id)?.unreadCount, 8)
        XCTAssertTrue(state.activity.subscribedDiscussions.contains { $0.id == thread.id })
        XCTAssertTrue(state.activity.mentions.contains { $0.id == mention.id })
        state.readDiscussion(thread.id); state.readMention(mention.id)
        XCTAssertEqual(state.conversation(space.id)?.unreadCount, 8)
    }

    func testReadingOneMentionKeepsOtherMessagesOrderAndSubscriptions() throws {
        var state = ChatListState()
        let mention = try XCTUnwrap(state.activity.mentions.first { state.conversation($0.conversationID)?.section == "Чат" })
        let count = try XCTUnwrap(state.conversation(mention.conversationID)).unreadCount
        let order = state.activity.mentions.map(\.id)
        let subscribed = state.activity.subscribedDiscussions.map(\.id)
        state.readMention(mention.id)
        XCTAssertEqual(state.conversation(mention.conversationID)?.unreadCount, count - 1)
        XCTAssertEqual(state.activity.mentions.map(\.id), order)
        XCTAssertEqual(state.activity.subscribedDiscussions.map(\.id), subscribed)
        XCTAssertEqual(state.conversation(space.id)?.unreadCount, 11)
    }

    func testMentionsCoverGroupChannelAndGlobalPersonalDialogue() {
        let state = ChatListState()
        let contexts = state.activity.mentions.compactMap { state.conversation($0.conversationID) }
        XCTAssertTrue(contexts.contains { $0.kind == .channel })
        XCTAssertTrue(contexts.contains { !$0.isPersonal && $0.kind == .chat })
        XCTAssertTrue(contexts.contains { $0.isPersonal && $0.parentSpaceID == nil })
        XCTAssertEqual(Set(state.activity.mentions.map(\.id)).count, state.activity.mentions.count)
    }

    func testSendingThreadReplyKeepsUnreadAndMovesDiscussionToTop() throws {
        var state = ChatListState()
        let thread = try XCTUnwrap(state.activity.subscribedDiscussions.last)
        let unread = state.conversation(thread.conversationID)?.unreadCount
        let message = try XCTUnwrap(state.sendMessage("Проверка завершена", conversationID: thread.conversationID,
                                                    threadID: thread.id, at: now))
        XCTAssertEqual(message.threadID, thread.id)
        XCTAssertTrue(message.isOutgoing)
        XCTAssertEqual(state.activity.subscribedDiscussions.first?.id, thread.id)
        XCTAssertEqual(state.conversation(thread.conversationID)?.unreadCount, unread)
        XCTAssertEqual(state.conversation(thread.conversationID)?.message, "Проверка завершена")
        XCTAssertNil(state.sendMessage("  ", conversationID: thread.conversationID, threadID: thread.id))
    }

    func testChannelMentionReplyGoesToDiscussionNotAnnouncementFeed() throws {
        var state = ChatListState()
        let mention = try XCTUnwrap(state.activity.mentions.first { state.conversation($0.conversationID)?.kind == .channel })
        let feed = state.activity.feed(mention.conversationID)
        XCTAssertNil(state.sendMessage("Новая публикация", conversationID: mention.conversationID))
        let id = try XCTUnwrap(state.activity.ensureDiscussion(for: mention.id))
        let message = try XCTUnwrap(state.sendMessage("Посмотрела", conversationID: mention.conversationID,
                                                    threadID: id, replyTo: mention.id, at: now))
        XCTAssertEqual(message.replyToMessageID, mention.id)
        XCTAssertEqual(state.activity.feed(mention.conversationID), feed)
        XCTAssertFalse(try XCTUnwrap(state.activity.discussion(id)).isSubscribed)
        XCTAssertEqual(state.activity.ensureDiscussion(for: mention.id), id)
    }

    func testPersonalReplyKeepsNoSpaceOrThreadAndUpdatesRecentFive() throws {
        var state = ChatListState()
        let mention = try XCTUnwrap(state.activity.mentions.first { state.conversation($0.conversationID)?.isPersonal == true })
        let message = try XCTUnwrap(state.sendMessage("Да, проверю", conversationID: mention.conversationID,
                                                    replyTo: mention.id, at: now))
        XCTAssertNil(message.threadID)
        XCTAssertEqual(message.replyToMessageID, mention.id)
        XCTAssertNil(state.conversation(mention.conversationID)?.parentSpaceID)
        XCTAssertEqual(state.recentPersonalConversations.first?.id, mention.conversationID)
        XCTAssertEqual(state.conversation(mention.conversationID)?.unreadCount, 2)
    }

    func testInvalidCrossConversationReplyAndUnknownActionsDoNotMutateMessages() throws {
        var state = ChatListState()
        let thread = try XCTUnwrap(state.activity.subscribedDiscussions.first)
        let personal = try XCTUnwrap(state.recentPersonalConversations.first)
        let messages = state.activity.messages
        XCTAssertNil(state.sendMessage("Неверный контекст", conversationID: personal.id, threadID: thread.id))
        XCTAssertNil(state.sendMessage("Неверный ответ", conversationID: personal.id, replyTo: thread.rootMessageID))
        state.readMention(UUID()); state.readDiscussion(UUID()); state.activity.unsubscribe(UUID())
        XCTAssertEqual(state.activity.messages, messages)
    }

    func testMainReadActionsAlsoReadSharedActivityMessages() throws {
        var state = ChatListState()
        state.markRead(space.id)
        XCTAssertTrue(state.activity.messages.filter { state.conversation($0.conversationID)?.isChild == true }.allSatisfy { !$0.isUnread })
        state.markAllRead()
        XCTAssertTrue(state.activity.messages.allSatisfy { !$0.isUnread })
        state.restore()
        XCTAssertTrue(state.activity.messages.contains(where: \.isUnread))
    }

    func testApplicationsHaveActiveAndMissedSessionsAndResourceDestinations() {
        let state = ChatListState()
        let events = state.activity.applications(now: now)
        XCTAssertEqual(events.count, 4)
        XCTAssertEqual(Set(events.map(\.id)).count, 4)
        XCTAssertEqual(events.filter { $0.sessionID != nil }.count, 2)
        XCTAssertTrue(events.contains { $0.resource.tab == .notes })
        XCTAssertTrue(events.contains { $0.resource.tab == .board })
        XCTAssertTrue(events.allSatisfy { state.conversation($0.resource.conversationID)?.section == "Почта" })
        let roomIDs = events.filter { $0.sessionID != nil }.map { $0.resource.id }
        XCTAssertEqual(Set(roomIDs).count, 1)
    }

    func testApplicationWindowParticipationAccessAndDuplicates() throws {
        var state = ChatListState()
        let room = try XCTUnwrap(state.activity.resources.first { $0.tab == .voice })
        let active = VoiceSession(id: UUID(), resourceID: room.id, lastActivityAt: now.addingTimeInterval(-10 * 86400),
                                  isActive: true, didParticipate: false, participants: [])
        let visited = VoiceSession(id: UUID(), resourceID: room.id, lastActivityAt: now.addingTimeInterval(-60),
                                   isActive: false, didParticipate: true, participants: [])
        let old = VoiceSession(id: UUID(), resourceID: room.id, lastActivityAt: now.addingTimeInterval(-10 * 86400),
                               isActive: false, didParticipate: false, participants: [])
        state.activity.sessions += [active, active, visited, old]
        let events = state.activity.applications(now: now)
        XCTAssertEqual(events.filter { $0.id == active.id }.count, 1)
        XCTAssertFalse(events.contains { $0.id == visited.id || $0.id == old.id })
        state.activity.events.append(state.activity.events[0])
        XCTAssertEqual(state.activity.applications(now: now).filter { $0.id == state.activity.events[0].id }.count, 1)
        state.activity.resources = state.activity.resources.map { resource in
            var value = resource; value.isAccessible = false; return value
        }
        XCTAssertTrue(state.activity.applications(now: now).isEmpty)
    }

    func testMuteDoesNotFilterActivitiesOrCreateResourceCopiesForSameName() throws {
        var state = ChatListState()
        let before = state.activity.subscribedDiscussions.map(\.id)
        let mentions = state.activity.mentions.map(\.id)
        state.toggleMuted(space.id)
        XCTAssertEqual(state.activity.subscribedDiscussions.map(\.id), before)
        XCTAssertEqual(state.activity.mentions.map(\.id), mentions)
        let resources = state.activity.resources
        let ids = Set(resources.map(\.conversationID))
        XCTAssertEqual(ids.count, 1)
        let siblings = state.conversations.filter { $0.title == "Разработка" && !ids.contains($0.id) }
        XCTAssertTrue(siblings.allSatisfy { sibling in !resources.contains { $0.conversationID == sibling.id } })
    }

    func testMovingRowsDoesNotChangeMainOrderIdentityCountersOrPersonalChronology() throws {
        var state = ChatListState()
        let section = space.sections[0]
        let rows = state.spaceConversations(space.id, sectionID: section.id)
        let main = state.visibleConversations.map(\.id)
        let personal = state.recentPersonalConversations.map(\.id)
        let snapshot = state.conversations
        XCTAssertTrue(state.moveRow(rows[2].id, relativeTo: rows[0].id, after: false))
        XCTAssertEqual(state.spaceConversations(space.id, sectionID: section.id).map(\.id), [rows[2].id, rows[0].id, rows[1].id])
        XCTAssertEqual(state.visibleConversations.map(\.id), main)
        XCTAssertEqual(state.recentPersonalConversations.map(\.id), personal)
        XCTAssertEqual(state.conversations, snapshot)
    }

    func testInvalidCrossSectionAndPersonalMovesAreRejected() throws {
        var state = ChatListState()
        let a = state.spaceConversations(space.id, sectionID: space.sections[0].id)
        let b = state.spaceConversations(space.id, sectionID: space.sections[1].id)
        XCTAssertFalse(state.moveRow(a[0].id, relativeTo: b[0].id, after: true))
        XCTAssertFalse(state.moveRow(a[0].id, relativeTo: a[0].id, after: true))
        XCTAssertFalse(state.moveRow(UUID(), relativeTo: a[0].id, after: true))
        XCTAssertFalse(state.moveRow(state.recentPersonalConversations[0].id, relativeTo: a[0].id, after: true))
        XCTAssertEqual(state.spaceConversations(space.id, sectionID: space.sections[0].id), a)
    }

    func testMovingCollapsedSectionKeepsInternalOrderAndPersonalState() {
        var state = ChatListState()
        var presentation = SpaceHomeState()
        let last = space.sections[2]
        let rows = state.spaceConversations(space.id, sectionID: last.id)
        presentation.toggleSection(last.id)
        presentation.personalExpanded = false
        state.moveSection(last.id, relativeTo: space.sections[0].id, after: false, spaceID: space.id)
        XCTAssertEqual(state.orderedSections(space.id).map(\.id), [last.id, space.sections[0].id, space.sections[1].id])
        XCTAssertFalse(presentation.isExpanded(last.id))
        XCTAssertFalse(presentation.personalExpanded)
        XCTAssertEqual(state.spaceConversations(space.id, sectionID: last.id), rows)
        XCTAssertEqual(state.spaceConversations(space.id).first?.title, "#general — Важные объявления")
    }

    func testOrdersStayScopedToSpaceAndRestoreResetsThem() {
        var state = ChatListState()
        let otherID = UUID()
        let other = ProductSpace(id: otherID, title: "Другая команда", announcementChannel: space.announcementChannel, sections: space.sections)
        let root = Conversation(id: otherID, title: other.title, message: "", time: "", initials: "ДК", avatarTint: .accent, space: other, order: 99)
        state = ChatListState(conversations: state.conversations + [root])
        state.moveSection(space.sections[2].id, relativeTo: space.sections[0].id, after: false, spaceID: space.id)
        XCTAssertEqual(state.orderedSections(otherID).map(\.id), space.sections.map(\.id))
        state.restore()
        XCTAssertEqual(state.orderedSections(space.id).map(\.id), space.sections.map(\.id))
    }

    func testEmptyNewDialogueAndFirstLocalMessage() throws {
        var state = ChatListState()
        state.createChat(named: "Новый собеседник")
        let conversation = try XCTUnwrap(state.conversations.first { $0.title == "Новый собеседник" })
        XCTAssertTrue(state.activity.feed(conversation.id).isEmpty)
        XCTAssertFalse(state.recentPersonalConversations.contains { $0.id == conversation.id })
        XCTAssertNotNil(state.sendMessage("Привет", conversationID: conversation.id, at: now))
        XCTAssertEqual(state.activity.feed(conversation.id).count, 1)
        XCTAssertEqual(state.recentPersonalConversations.first?.id, conversation.id)
    }

    func testPresentationGroupsAndTabsPersistIndependently() {
        var activity = ActivitiesPresentation()
        activity.toggle(.discussions); activity.toggle(.personal)
        activity.scrollID = UUID()
        activity.toggle(.discussions)
        XCTAssertEqual(activity.collapsed, [.personal])
        XCTAssertNotNil(activity.scrollID)
        var dialogue = DialoguePresentation()
        dialogue.tab = .board; dialogue.draft = "Черновик"
        dialogue.resourceScrollIDs[.board] = UUID()
        dialogue.tab = .messages
        XCTAssertEqual(dialogue.draft, "Черновик")
        XCTAssertNotNil(dialogue.resourceScrollIDs[.board])
    }

    func testActivitiesFromNestedThreadHaveSingleInstanceAndReturnToThread() {
        var navigation = AppNavigationState()
        let thread = AppRoute.thread(UUID(), composing: false)
        navigation.open(.space(space.id)); navigation.openActivities(); navigation.open(thread)
        navigation.openActivities()
        XCTAssertEqual(navigation.path.filter { $0 == .activities }.count, 1)
        navigation.goBack()
        XCTAssertEqual(navigation.path.last, thread)
    }
    func testReadingDiscussionAlsoReadsItsUnreadRootMention() throws {
        let channel = Conversation(title: "Канал", message: "@Вы, проверьте документ", time: "12:00",
                                   initials: "К", avatarTint: .accent, kind: .channel,
                                   unreadMentionCount: 1, unreadCount: 1, order: 0)
        var state = ChatListState(conversations: [channel])
        let mention = try XCTUnwrap(state.activity.mentions.first)
        let id = try XCTUnwrap(state.activity.ensureDiscussion(for: mention.id))
        state.readDiscussion(id)
        XCTAssertFalse(try XCTUnwrap(state.activity.message(mention.id)).isUnread)
        XCTAssertEqual(state.conversation(channel.id)?.unreadCount, 0)
        XCTAssertEqual(state.conversation(channel.id)?.unreadMentionCount, 0)
    }

    func testMentionUsesUserIdentityNotAtCharacterOrOtherUser() {
        let conversationID = UUID()
        let other = ChatMessage(id: UUID(), conversationID: conversationID, threadID: nil, author: "Паша",
                                text: "@другой", sentAt: now, isOutgoing: false,
                                mentionedUserIDs: [UUID()], isUnread: true, replyToMessageID: nil)
        let textOnly = ChatMessage(id: UUID(), conversationID: conversationID, threadID: nil, author: "Паша",
                                   text: "@Вы", sentAt: now, isOutgoing: false,
                                   isUnread: true, replyToMessageID: nil)
        let mine = ChatMessage(id: UUID(), conversationID: conversationID, threadID: nil, author: "Паша",
                               text: "@Вы", sentAt: now, isOutgoing: false,
                               mentionedUserIDs: [DemoUser.id], isUnread: true, replyToMessageID: nil)
        XCTAssertFalse(other.mentionsMe)
        XCTAssertFalse(textOnly.mentionsMe)
        XCTAssertTrue(mine.mentionsMe)
    }

    func testResourceTabsRemainAvailableWhenChannelResourcesAreEmpty() throws {
        var state = ChatListState()
        let channel = try XCTUnwrap(state.conversations.first { $0.hasTeamResources })
        XCTAssertEqual(channel.section, "Почта")
        state.activity.resources = []
        XCTAssertTrue(try XCTUnwrap(state.conversation(channel.id)).hasTeamResources)
        XCTAssertTrue(state.activity.applications(now: now).isEmpty)
        XCTAssertTrue(state.conversations.filter { $0.title == "Разработка" && $0.id != channel.id }
            .allSatisfy { !$0.hasTeamResources })
    }

}
