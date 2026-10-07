import Foundation

enum DemoUser {
    static let id = UUID(uuidString: "00000000-0000-0000-0000-000000002000")!
}

struct ChatMessage: Identifiable, Equatable {
    let id: UUID
    let conversationID: UUID
    var threadID: UUID?
    let author: String
    let text: String
    let sentAt: Date
    let isOutgoing: Bool
    let mentionedUserIDs: Set<UUID>
    var mentionsMe: Bool { mentionedUserIDs.contains(DemoUser.id) }
    var isUnread: Bool
    let replyToMessageID: UUID?

    init(id: UUID, conversationID: UUID, threadID: UUID?, author: String, text: String,
         sentAt: Date, isOutgoing: Bool, mentionsMe: Bool = false,
         mentionedUserIDs: Set<UUID>? = nil, isUnread: Bool, replyToMessageID: UUID?) {
        self.id = id; self.conversationID = conversationID; self.threadID = threadID
        self.author = author; self.text = text; self.sentAt = sentAt; self.isOutgoing = isOutgoing
        self.mentionedUserIDs = mentionedUserIDs ?? (mentionsMe ? [DemoUser.id] : [])
        self.isUnread = isUnread; self.replyToMessageID = replyToMessageID
    }
}

struct Discussion: Identifiable, Equatable {
    let id: UUID
    let conversationID: UUID
    let rootMessageID: UUID
    let title: String
    var isSubscribed: Bool
}

enum DialogueTab: String, CaseIterable, Identifiable, Hashable {
    case messages = "Сообщения"
    case voice = "Голосовая комната"
    case board = "Доска"
    case notes = "Заметки"
    var id: Self { self }
    var symbol: String {
        switch self {
        case .messages: return "bubble.left"
        case .voice: return "video"
        case .board: return "rectangle.split.3x1"
        case .notes: return "note.text"
        }
    }
}

struct TeamResource: Identifiable, Equatable {
    let id: UUID
    let conversationID: UUID
    let tab: DialogueTab
    let title: String
    let text: String
    var updatedAt: Date? = nil
    var updatedBy = "Команда"
    var isAccessible = true
}

struct ResourceEvent: Identifiable, Equatable {
    let id: UUID
    let resourceID: UUID
    let happenedAt: Date
    let detail: String
}

struct VoiceSession: Identifiable, Equatable {
    let id: UUID
    let resourceID: UUID
    let lastActivityAt: Date
    let isActive: Bool
    let didParticipate: Bool
    let participants: [String]
}

struct ApplicationActivity: Identifiable {
    let id: UUID
    let resource: TeamResource
    let at: Date
    let detail: String
    let sessionID: UUID?
}

enum ActivityGroup: String, CaseIterable, Identifiable, Hashable {
    case discussions = "Обсуждения"
    case mentions = "Упоминания"
    case personal = "Личные сообщения"
    case applications = "Приложения"
    var id: Self { self }
}

struct ActivitiesPresentation {
    var collapsed: Set<ActivityGroup> = []
    var scrollID: UUID?
    mutating func toggle(_ group: ActivityGroup) {
        if !collapsed.insert(group).inserted { collapsed.remove(group) }
    }
}

struct DialoguePresentation {
    var tab: DialogueTab = .messages
    var scrollID: UUID?
    var resourceScrollIDs: [DialogueTab: UUID] = [:]
    var selectedNoteID: UUID?
    var draft = ""
}

struct ActivityStore {
    private(set) var messages: [ChatMessage] = []
    private(set) var discussions: [Discussion] = []
    var resources: [TeamResource] = []
    var events: [ResourceEvent] = []
    var sessions: [VoiceSession] = []

    init(conversations: [Conversation]) {
        let base = ISO8601DateFormatter().date(from: "2026-10-07T13:00:00+03:00")!
        for conversation in conversations where !conversation.isSpace && conversation.message != "Пока нет сообщений" {
            let at = conversation.lastMessageAt ?? Self.legacyDate(conversation.time, base: base)
            let count = max(1, conversation.unreadCount)
            let introID = UUID()
            messages.append(ChatMessage(id: introID, conversationID: conversation.id, threadID: nil,
                                        author: conversation.sender == "Вы" ? conversation.title : conversation.sender ?? conversation.title,
                                        text: "Обсудим задачи и ближайшие шаги команды.",
                                        sentAt: at.addingTimeInterval(-600), isOutgoing: false,
                                        mentionsMe: false, isUnread: false, replyToMessageID: nil))
            if conversation.kind == .chat {
                messages.append(ChatMessage(id: UUID(), conversationID: conversation.id, threadID: nil,
                                            author: "Вы", text: "Спасибо, посмотрю материалы.",
                                            sentAt: at.addingTimeInterval(-300), isOutgoing: true,
                                            mentionsMe: false, isUnread: false, replyToMessageID: nil))
            }
            for index in 0..<count {
                let last = index == count - 1
                let outgoing = last && conversation.sender == "Вы" && conversation.unreadCount == 0
                messages.append(ChatMessage(id: UUID(), conversationID: conversation.id, threadID: nil,
                                            author: conversation.sender ?? conversation.title,
                                            text: last ? conversation.message : "Обновление \(index + 1): материалы готовы к проверке.",
                                            sentAt: at.addingTimeInterval(Double(index - count + 1) * 60),
                                            isOutgoing: outgoing,
                                            mentionsMe: index >= count - conversation.unreadMentionCount,
                                            isUnread: conversation.unreadCount > 0, replyToMessageID: nil))
            }
            if conversation.section == "Чат" && ["Разработка", "QA"].contains(conversation.title) {
                let id = UUID()
                discussions.append(Discussion(id: id, conversationID: conversation.id, rootMessageID: introID,
                                              title: conversation.title == "QA" ? "Регресс перед релизом" : "Сборка для проверки",
                                              isSubscribed: true))
                let replyCount = conversation.title == "QA" ? 4 : 2
                let indices = messages.indices.filter { messages[$0].conversationID == conversation.id && messages[$0].isUnread }
                for index in indices.suffix(replyCount) { messages[index].threadID = id }
            }
        }
        if let anna = conversations.first(where: { $0.isPersonal && $0.title == "Анна Смирнова" }),
           let index = messages.firstIndex(where: { $0.conversationID == anna.id && $0.isUnread && $0.mentionsMe })
                ?? messages.firstIndex(where: { $0.conversationID == anna.id && $0.isUnread }) {
            let old = messages[index]
            messages[index] = ChatMessage(id: old.id, conversationID: old.conversationID, threadID: nil,
                                         author: "Анна", text: "@Вы, сможете проверить макет?", sentAt: old.sentAt,
                                         isOutgoing: false, mentionsMe: true, isUnread: true, replyToMessageID: nil)
        }
        if let channel = conversations.first(where: \.hasTeamResources) {
            messages.append(ChatMessage(id: UUID(), conversationID: channel.id, threadID: nil,
                                        author: "Дима", text: "@Вы, посмотрите документацию.",
                                        sentAt: base.addingTimeInterval(-2400), isOutgoing: false,
                                        mentionsMe: true, isUnread: false, replyToMessageID: nil))
            let voice = TeamResource(id: UUID(), conversationID: channel.id, tab: .voice,
                                     title: "Комната разработки", text: "Голосовая комната команды")
            let board = TeamResource(id: UUID(), conversationID: channel.id, tab: .board,
                                     title: "Доска разработки", text: "Задачи команды")
            let note = TeamResource(id: UUID(), conversationID: channel.id, tab: .notes,
                                    title: "Чек-лист релиза", text: "1. Проверить сборку\n2. Выполнить регресс\n3. Обновить документацию",
                                    updatedAt: base.addingTimeInterval(-600), updatedBy: "Дима")
            let architecture = TeamResource(id: UUID(), conversationID: channel.id, tab: .notes,
                                            title: "Решения по архитектуре", text: "Общая модель сообщений, устойчивые идентификаторы и локальные состояния прототипа.",
                                            updatedAt: base.addingTimeInterval(-86400), updatedBy: "Дима")
            resources = [voice, board, note, architecture]
            events = [ResourceEvent(id: UUID(), resourceID: note.id, happenedAt: base.addingTimeInterval(-600), detail: "Дима обновил заметку"),
                      ResourceEvent(id: UUID(), resourceID: board.id, happenedAt: base.addingTimeInterval(-69600), detail: "Олег обновил задачу «Проверить сборку»")]
            sessions = [VoiceSession(id: UUID(), resourceID: voice.id, lastActivityAt: base.addingTimeInterval(-900),
                                     isActive: true, didParticipate: false, participants: ["Паша", "Олег", "Дима"]),
                        VoiceSession(id: UUID(), resourceID: voice.id, lastActivityAt: base.addingTimeInterval(-74400),
                                     isActive: false, didParticipate: false, participants: ["Паша", "Олег"])]
        }
    }

    private static func legacyDate(_ value: String, base: Date) -> Date {
        let parts = value.split(separator: ":").compactMap { Int($0) }
        if parts.count == 2 {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "Europe/Moscow")!
            return calendar.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: base) ?? base
        }
        return base.addingTimeInterval(-86400)
    }

    func message(_ id: UUID) -> ChatMessage? { messages.first { $0.id == id } }
    func discussion(_ id: UUID) -> Discussion? { discussions.first { $0.id == id } }
    func resource(_ id: UUID) -> TeamResource? { resources.first { $0.id == id } }
    func session(_ id: UUID) -> VoiceSession? { sessions.first { $0.id == id } }

    func feed(_ conversationID: UUID, threadID: UUID? = nil) -> [ChatMessage] {
        messages.filter { $0.conversationID == conversationID && $0.threadID == threadID }.sorted {
            $0.sentAt == $1.sentAt ? $0.id.uuidString < $1.id.uuidString : $0.sentAt < $1.sentAt
        }
    }

    func replies(_ threadID: UUID) -> [ChatMessage] {
        guard let discussion = discussion(threadID) else { return [] }
        return feed(discussion.conversationID, threadID: threadID)
    }

    func lastMessage(_ threadID: UUID) -> ChatMessage? {
        replies(threadID).last ?? discussion(threadID).flatMap { message($0.rootMessageID) }
    }

    var subscribedDiscussions: [Discussion] {
        discussions.filter(\.isSubscribed).sorted {
            let first = lastMessage($0.id)?.sentAt ?? .distantPast
            let second = lastMessage($1.id)?.sentAt ?? .distantPast
            return first == second ? $0.id.uuidString < $1.id.uuidString : first > second
        }
    }

    var mentions: [ChatMessage] {
        messages.filter(\.mentionsMe).sorted {
            $0.sentAt == $1.sentAt ? $0.id.uuidString < $1.id.uuidString : $0.sentAt > $1.sentAt
        }
    }

    func applications(now: Date = Date()) -> [ApplicationActivity] {
        let cutoff = now.addingTimeInterval(-7 * 86400)
        var result: [ApplicationActivity] = []
        var seen = Set<UUID>()
        for event in events where event.happenedAt >= cutoff && event.happenedAt <= now {
            guard seen.insert(event.id).inserted, let resource = resource(event.resourceID), resource.isAccessible else { continue }
            result.append(ApplicationActivity(id: event.id, resource: resource, at: event.happenedAt, detail: event.detail, sessionID: nil))
        }
        for session in sessions {
            guard session.lastActivityAt <= now,
                  session.isActive || (!session.didParticipate && session.lastActivityAt >= cutoff),
                  seen.insert(session.id).inserted, let resource = resource(session.resourceID), resource.isAccessible else { continue }
            result.append(ApplicationActivity(id: session.id, resource: resource, at: session.lastActivityAt,
                                              detail: session.isActive ? "Идёт сейчас · \(session.participants.count) участника" : "Пропущена",
                                              sessionID: session.id))
        }
        return result.sorted { $0.at == $1.at ? $0.id.uuidString < $1.id.uuidString : $0.at > $1.at }
    }

    mutating func unsubscribe(_ id: UUID) {
        guard let index = discussions.firstIndex(where: { $0.id == id }) else { return }
        discussions[index].isSubscribed = false
    }

    mutating func markMessageRead(_ id: UUID) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[index].isUnread = false
    }

    mutating func markThreadRead(_ id: UUID) {
        guard let thread = discussion(id) else { return }
        for index in messages.indices where messages[index].threadID == id || messages[index].id == thread.rootMessageID {
            messages[index].isUnread = false
        }
    }

    mutating func markConversationRead(_ id: UUID) {
        for index in messages.indices where messages[index].conversationID == id { messages[index].isUnread = false }
    }

    @discardableResult
    mutating func send(_ text: String, conversation: Conversation, threadID: UUID? = nil,
                       replyTo: UUID? = nil, at: Date = Date()) -> ChatMessage? {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !conversation.isSpace else { return nil }
        if let threadID {
            guard discussion(threadID)?.conversationID == conversation.id else { return nil }
        }
        if let replyTo {
            guard let target = message(replyTo), target.conversationID == conversation.id,
                  target.threadID == threadID || threadID.flatMap({ discussion($0)?.rootMessageID }) == target.id else { return nil }
        }
        guard conversation.kind != .channel || threadID != nil else { return nil }
        let value = ChatMessage(id: UUID(), conversationID: conversation.id, threadID: threadID,
                                author: "Вы", text: text, sentAt: at, isOutgoing: true,
                                mentionsMe: false, isUnread: false, replyToMessageID: replyTo)
        messages.append(value)
        return value
    }

    mutating func ensureDiscussion(for messageID: UUID) -> UUID? {
        guard let message = message(messageID) else { return nil }
        if let threadID = message.threadID { return threadID }
        if let existing = discussions.first(where: { $0.rootMessageID == messageID }) { return existing.id }
        let discussion = Discussion(id: UUID(), conversationID: message.conversationID,
                                    rootMessageID: messageID, title: String(message.text.prefix(80)), isSubscribed: false)
        discussions.append(discussion)
        return discussion.id
    }
}

extension ChatListState {
    mutating func readMention(_ id: UUID) {
        guard let message = activity.message(id) else { return }
        activity.markMessageRead(id)
        synchronizeUnread(message.conversationID)
    }

    mutating func readDiscussion(_ id: UUID) {
        guard let thread = activity.discussion(id) else { return }
        activity.markThreadRead(id)
        synchronizeUnread(thread.conversationID)
    }

    mutating func synchronizeUnread(_ id: UUID) {
        let messages = activity.messages.filter { $0.conversationID == id && $0.isUnread && !$0.isOutgoing }
        update(id) {
            $0.unreadCount = messages.count
            $0.unreadMentionCount = messages.filter(\.mentionsMe).count
        }
        recalculateSpaceCounts()
    }

    @discardableResult
    mutating func sendMessage(_ text: String, conversationID: UUID, threadID: UUID? = nil,
                              replyTo: UUID? = nil, at: Date = Date()) -> ChatMessage? {
        guard let conversation = conversation(conversationID),
              let message = activity.send(text, conversation: conversation, threadID: threadID, replyTo: replyTo, at: at) else { return nil }
        updateLastMessage(conversationID, text: message.text, at: message.sentAt)
        update(conversationID) { $0.sender = "Вы" }
        return message
    }
}

struct SpaceStructureOrder {
    private var sections: [UUID: [UUID]] = [:]
    private var rows: [String: [UUID]] = [:]

    func sortedSections(_ space: ProductSpace) -> [SpaceSection] {
        sorted(space.sections, order: sections[space.id, default: []], id: \.id)
    }

    func sortedRows(_ values: [Conversation], spaceID: UUID, sectionID: UUID?) -> [Conversation] {
        guard let sectionID else { return values }
        return sorted(values, order: rows[key(spaceID, sectionID), default: []], id: \.id)
    }

    mutating func moveSection(_ id: UUID, relativeTo target: UUID, after: Bool, space: ProductSpace) -> Bool {
        var order = sortedSections(space).map(\.id)
        guard move(id, relativeTo: target, after: after, in: &order) else { return false }
        sections[space.id] = order
        return true
    }

    mutating func moveRow(_ id: UUID, relativeTo target: UUID, after: Bool, values: [Conversation], spaceID: UUID, sectionID: UUID) -> Bool {
        var order = sortedRows(values, spaceID: spaceID, sectionID: sectionID).map(\.id)
        guard move(id, relativeTo: target, after: after, in: &order) else { return false }
        rows[key(spaceID, sectionID)] = order
        return true
    }

    private func key(_ space: UUID, _ section: UUID) -> String { "\(space):\(section)" }
    private func sorted<T>(_ values: [T], order: [UUID], id: KeyPath<T, UUID>) -> [T] {
        let ranks = Dictionary(uniqueKeysWithValues: order.enumerated().map { ($0.element, $0.offset) })
        return values.enumerated().sorted {
            let a = ranks[$0.element[keyPath: id]] ?? (order.count + $0.offset)
            let b = ranks[$1.element[keyPath: id]] ?? (order.count + $1.offset)
            return a < b
        }.map(\.element)
    }

    private func move(_ id: UUID, relativeTo target: UUID, after: Bool, in values: inout [UUID]) -> Bool {
        guard id != target, let source = values.firstIndex(of: id), values.contains(target) else { return false }
        let original = values
        values.remove(at: source)
        guard let index = values.firstIndex(of: target) else { return false }
        values.insert(id, at: index + (after ? 1 : 0))
        return values != original
    }
}

extension ChatListState {
    func orderedSections(_ spaceID: UUID) -> [SpaceSection] {
        conversation(spaceID)?.space.map { structureOrder.sortedSections($0) } ?? []
    }

    @discardableResult
    mutating func moveSection(_ id: UUID, relativeTo target: UUID, after: Bool, spaceID: UUID) -> Bool {
        guard let space = conversation(spaceID)?.space else { return false }
        return structureOrder.moveSection(id, relativeTo: target, after: after, space: space)
    }

    @discardableResult
    mutating func moveRow(_ id: UUID, relativeTo target: UUID, after: Bool) -> Bool {
        guard let source = conversation(id), let destination = conversation(target),
              let spaceID = source.parentSpaceID, let sectionID = source.sectionID,
              destination.parentSpaceID == spaceID, destination.sectionID == sectionID else { return false }
        return structureOrder.moveRow(id, relativeTo: target, after: after,
                                      values: spaceConversations(spaceID, sectionID: sectionID), spaceID: spaceID, sectionID: sectionID)
    }
}
