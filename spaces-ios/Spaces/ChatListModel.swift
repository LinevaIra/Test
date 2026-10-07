import Foundation

private func demoID(_ number: Int) -> UUID {
    UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012d", number))")!
}

private func demoDate(_ value: String) -> Date {
    ISO8601DateFormatter().date(from: value)!
}

enum ChatFilter: String, CaseIterable, Identifiable {
    case all = "Все"
    case unread = "Непрочитанные"
    case spaces = "Пространства"

    var id: Self { self }
}

enum AvatarTint: String {
    case accent = "00806D"
    case orange = "F3982D"
    case blue = "4789E8"
    case teal = "32B7A1"
    case pink = "E7779C"
    case purple = "A466C9"
}

enum ConversationKind: String, Hashable {
    case chat = "Чат"
    case channel = "Канал"
}

struct SpaceChannel: Equatable {
    enum Visibility: Equatable {
        case `public`
        case `private`
    }

    let title: String
    let purpose: String
    let visibility: Visibility
}

struct SpaceSection: Identifiable, Equatable {
    var id = UUID()
    let title: String
    let channels: [SpaceChannel]
}

struct ProductSpace: Equatable {
    let id: UUID
    let title: String
    let announcementChannel: SpaceChannel
    let sections: [SpaceSection]

    var sectionSummary: String {
        sections.map(\.title).joined(separator: " · ")
    }

    var searchTerms: [String] {
        [announcementChannel.title, announcementChannel.purpose]
            + sections.flatMap { [$0.title] + $0.channels.map(\.title) }
    }

    static let sber = ProductSpace(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        title: "Проект Сбер.продукт",
        announcementChannel: SpaceChannel(title: "#general", purpose: "Важные объявления", visibility: .public),
        sections: ["Чат", "Почта", "ВКС"].enumerated().map { index, title in
            SpaceSection(id: demoID(101 + index), title: title, channels: ["РО", "Разработка", "QA"].map {
                SpaceChannel(title: $0, purpose: title == "Чат" ? "Приватный чат" : "Приватный канал",
                             visibility: .private)
            })
        }
    )
}

struct Conversation: Identifiable, Equatable {
    let id: UUID
    let title: String
    var sender: String?
    var message: String
    let time: String
    let initials: String
    let avatarTint: AvatarTint
    let space: ProductSpace?
    let parentSpaceID: UUID?
    let kind: ConversationKind
    let section: String?
    let sectionID: UUID?
    let isPersonal: Bool
    let isListedOnMain: Bool
    var lastMessageAt: Date?
    var unreadMentionCount: Int
    var unreadCount: Int
    var isPinned: Bool
    var isMuted: Bool
    let order: Int

    var isSpace: Bool { space != nil }
    var isChild: Bool { parentSpaceID != nil }

    func displayTime(relativeTo now: Date = Date()) -> String {
        guard let date = lastMessageAt else { return time }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Moscow")!
        if calendar.isDate(date, inSameDayAs: now) {
            let formatter = DateFormatter()
            formatter.timeZone = calendar.timeZone
            formatter.locale = Locale(identifier: "ru_RU")
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) { return "вчера" }
        let formatter = DateFormatter()
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }

    init(id: UUID = UUID(), title: String, sender: String? = nil, message: String,
         time: String, initials: String, avatarTint: AvatarTint, space: ProductSpace? = nil,
         parentSpaceID: UUID? = nil, kind: ConversationKind = .chat, section: String? = nil,
         sectionID: UUID? = nil, isPersonal: Bool = false, isListedOnMain: Bool = true,
         lastMessageAt: Date? = nil, unreadMentionCount: Int = 0, unreadCount: Int = 0, isPinned: Bool = false, isMuted: Bool = false, order: Int) {
        self.id = id
        self.title = title
        self.sender = sender
        self.message = message
        self.time = time
        self.initials = initials
        self.avatarTint = avatarTint
        self.space = space
        self.parentSpaceID = parentSpaceID
        self.kind = kind
        self.section = section
        self.sectionID = sectionID
        self.isPersonal = isPersonal
        self.isListedOnMain = isListedOnMain
        self.lastMessageAt = lastMessageAt
        self.unreadMentionCount = unreadMentionCount
        self.unreadCount = unreadCount
        self.isPinned = isPinned
        self.isMuted = isMuted
        self.order = order
    }

    func matchesContent(_ query: String) -> Bool {
        let terms = [title, message] + (isSpace ? [] : [sender ?? "", section ?? ""])
        return query.isEmpty || terms.contains { $0.localizedCaseInsensitiveContains(query) }
    }

    static let samples: [Conversation] = [
        Conversation(id: ProductSpace.sber.id, title: ProductSpace.sber.title, sender: "#general",
                     message: "Релиз запланирован на пятницу", time: "12:42", initials: "СП",
                     avatarTint: .accent, space: .sber, unreadCount: 12, isPinned: true, order: 0),
        Conversation(id: demoID(2), title: "Анна Смирнова", message: "Отлично, тогда до встречи!",
                     time: "12:38", initials: "АС", avatarTint: .orange, isPersonal: true,
                     lastMessageAt: demoDate("2026-10-07T12:38:00+03:00"), unreadCount: 2, order: 1),
        Conversation(title: "Команда продукта", sender: "Михаил", message: "Собрал заметки после встречи",
                     time: "12:21", initials: "КП", avatarTint: .teal, unreadCount: 5, order: 2),
        Conversation(id: demoID(4), title: "Алексей", sender: "Вы", message: "Спасибо, посмотрю сегодня",
                     time: "11:54", initials: "А", avatarTint: .blue, isPersonal: true,
                     lastMessageAt: demoDate("2026-10-07T11:54:00+03:00"), order: 3),
        Conversation(id: demoID(5), title: "Мария Козлова", message: "Отправила тебе фотографии",
                     time: "10:46", initials: "МК", avatarTint: .pink, isPersonal: true,
                     lastMessageAt: demoDate("2026-10-07T10:46:00+03:00"), order: 4),
        Conversation(title: "Выходные", sender: "Денис", message: "Кто идёт на прогулку?",
                     time: "вчера", initials: "В", avatarTint: .teal,
                     unreadCount: 8, isMuted: true, order: 5),
        Conversation(id: demoID(7), title: "Дмитрий", sender: "Вы", message: "Договорились 👍",
                     time: "вчера", initials: "Д", avatarTint: .purple, isPersonal: true,
                     lastMessageAt: demoDate("2026-10-06T18:20:00+03:00"), order: 6),
        Conversation(title: "Обсуждение релиза", sender: "Ольга", message: "Проверим финальный список задач",
                     time: "вчера", initials: "ОР", avatarTint: .orange, order: 7),
        Conversation(id: demoID(201), title: "#general — Важные объявления", message: "Релиз запланирован на пятницу",
                     time: "12:42", initials: "ВО", avatarTint: .accent,
                     parentSpaceID: ProductSpace.sber.id, kind: .channel, unreadCount: 3, order: 0),
        Conversation(id: demoID(203), title: "Разработка", sender: "Паша", message: "@Вы, проверьте сборку",
                     time: "12:35", initials: "Р", avatarTint: .teal,
                     parentSpaceID: ProductSpace.sber.id, section: "Чат", sectionID: ProductSpace.sber.sections[0].id,
                     unreadMentionCount: 1, unreadCount: 5, order: 1),
        Conversation(id: demoID(204), title: "QA", sender: "Вика", message: "@Вы, результаты регресса готовы",
                     time: "12:30", initials: "QA", avatarTint: .accent,
                     parentSpaceID: ProductSpace.sber.id, section: "Чат", sectionID: ProductSpace.sber.sections[0].id,
                     unreadMentionCount: 1, unreadCount: 4, order: 2),
        Conversation(id: demoID(202), title: "РО", message: "Согласовали план на неделю",
                     time: "11:40", initials: "РО", avatarTint: .accent,
                     parentSpaceID: ProductSpace.sber.id, section: "Чат",
                     sectionID: ProductSpace.sber.sections[0].id, isMuted: true, order: 0),
        Conversation(id: demoID(205), title: "РО", message: "Отправили итоговый протокол",
                     time: "10:20", initials: "РО", avatarTint: .accent,
                     parentSpaceID: ProductSpace.sber.id, kind: .channel, section: "Почта",
                     sectionID: ProductSpace.sber.sections[1].id, order: 0),
        Conversation(id: demoID(206), title: "Разработка", message: "Документация обновлена",
                     time: "вчера", initials: "Р", avatarTint: .teal,
                     parentSpaceID: ProductSpace.sber.id, kind: .channel, section: "Почта",
                     sectionID: ProductSpace.sber.sections[1].id, isMuted: true, order: 1),
        Conversation(id: demoID(207), title: "QA", message: "Чек-лист согласован",
                     time: "вчера", initials: "QA", avatarTint: .accent,
                     parentSpaceID: ProductSpace.sber.id, kind: .channel, section: "Почта",
                     sectionID: ProductSpace.sber.sections[1].id, order: 2),
        Conversation(id: demoID(208), title: "РО", message: "Обсудили приоритеты",
                     time: "вчера", initials: "РО", avatarTint: .accent,
                     parentSpaceID: ProductSpace.sber.id, kind: .channel, section: "ВКС",
                     sectionID: ProductSpace.sber.sections[2].id, isMuted: true, order: 0),
        Conversation(id: demoID(209), title: "Разработка", message: "Следующая встреча завтра",
                     time: "вчера", initials: "Р", avatarTint: .teal,
                     parentSpaceID: ProductSpace.sber.id, kind: .channel, section: "ВКС",
                     sectionID: ProductSpace.sber.sections[2].id, order: 1),
        Conversation(id: demoID(210), title: "QA", message: "Встреча завершена",
                     time: "вчера", initials: "QA", avatarTint: .accent,
                     parentSpaceID: ProductSpace.sber.id, kind: .channel, section: "ВКС",
                     sectionID: ProductSpace.sber.sections[2].id, isMuted: true, order: 2),
        Conversation(id: demoID(9), title: "Ирина Петрова", message: "Посмотрела материалы, спасибо",
                     time: "11:15", initials: "ИП", avatarTint: .blue,
                     isPersonal: true, isListedOnMain: false,
                     lastMessageAt: demoDate("2026-10-07T11:15:00+03:00"), unreadCount: 1, order: 8),
        Conversation(id: demoID(10), title: "Сергей Орлов", message: "До встречи на следующей неделе",
                     time: "вчера", initials: "СО", avatarTint: .purple,
                     isPersonal: true, isListedOnMain: false,
                     lastMessageAt: demoDate("2026-10-06T17:00:00+03:00"), order: 9)
    ]
}

/// A destination identifies a space or an exact dialogue, independently of unread state.
enum AppRoute: Hashable {
    case space(UUID)
    case dialogue(spaceID: UUID, conversationID: UUID, kind: ConversationKind)
    case personalDialogue(UUID)
    case activities
}

struct AppNavigationState {
    var path: [AppRoute] = []

    mutating func open(_ route: AppRoute) {
        guard path.last != route else { return }
        path.append(route)
    }

    mutating func openActivities() { open(.activities) }

    mutating func goBack() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }
}

/// Shared by all window sizes. Children stay in the model when read or muted.
struct ChatListState {
    private(set) var conversations: [Conversation]
    var query = ""
    var filter: ChatFilter = .all

    init(conversations: [Conversation] = Conversation.samples) {
        self.conversations = conversations
        recalculateSpaceCounts()
    }

    var unreadConversationCount: Int {
        conversations.filter { !$0.isChild && $0.isListedOnMain && $0.unreadCount > 0 }.count
    }

    var visibleConversations: [Conversation] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let roots = conversations.filter { !$0.isChild && $0.isListedOnMain }.sorted {
            if $0.isPinned != $1.isPinned { return $0.isPinned }
            return $0.order < $1.order
        }
        return roots.flatMap { root -> [Conversation] in
            switch filter {
            case .all: break
            case .unread: if root.unreadCount == 0 { return [] }
            case .spaces: if !root.isSpace { return [] }
            }
            guard let space = root.space else {
                return root.matchesContent(query) ? [root] : []
            }
            let children = conversations.filter {
                $0.parentSpaceID == root.id && !root.isMuted && !$0.isMuted && $0.unreadCount > 0
            }.sorted { $0.order < $1.order }
            // Exact section/channel terms (e.g. "РО") take precedence over a
            // coincidental substring in the product name (e.g. "Проект").
            let isContextTerm = !query.isEmpty && space.searchTerms.contains {
                $0.compare(query, options: .caseInsensitive) == .orderedSame
            }
            if query.isEmpty || (root.matchesContent(query) && !isContextTerm) {
                return [root] + children
            }
            let matchingChildren = children.filter { child in
                if isContextTerm {
                    let labels = [child.title, child.section ?? ""]
                        + child.title.components(separatedBy: " — ")
                    return labels.contains { $0.compare(query, options: .caseInsensitive) == .orderedSame }
                }
                return child.matchesContent(query)
            }
            let contextMatches = space.searchTerms.contains { $0.localizedCaseInsensitiveContains(query) }
            return !matchingChildren.isEmpty || contextMatches ? [root] + matchingChildren : []
        }
    }

    func conversation(_ id: UUID) -> Conversation? {
        conversations.first { $0.id == id }
    }

    func route(for conversation: Conversation) -> AppRoute? {
        guard self.conversation(conversation.id) != nil else { return nil }
        if conversation.isSpace { return .space(conversation.id) }
        if conversation.isPersonal && !conversation.isChild { return .personalDialogue(conversation.id) }
        guard let parentID = conversation.parentSpaceID,
              self.conversation(parentID)?.isSpace == true else { return nil }
        return .dialogue(spaceID: parentID, conversationID: conversation.id, kind: conversation.kind)
    }

    mutating func markRead(_ id: UUID) {
        guard let target = conversation(id) else { return }
        for index in conversations.indices {
            if conversations[index].id == id || (target.isSpace && conversations[index].parentSpaceID == id) {
                conversations[index].unreadCount = 0
                conversations[index].unreadMentionCount = 0
            }
        }
        recalculateSpaceCounts()
    }

    mutating func toggleMuted(_ id: UUID) {
        update(id) { $0.isMuted.toggle() }
    }

    mutating func togglePinned(_ id: UUID) {
        // Pinning belongs to roots, never moves a child out of its space.
        guard conversation(id)?.isChild == false else { return }
        update(id) { $0.isPinned.toggle() }
    }

    mutating func markAllRead() {
        for index in conversations.indices {
            conversations[index].unreadCount = 0
            conversations[index].unreadMentionCount = 0
        }
    }

    mutating func restore() { self = ChatListState() }

    @discardableResult
    mutating func createChat(named name: String) -> Bool {
        let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return false }
        let initials = title.split(whereSeparator: \.isWhitespace)
            .prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
        let rootOrder = conversations.filter { !$0.isChild }.map(\.order).min() ?? 0
        conversations.append(Conversation(title: title, message: "Пока нет сообщений",
                                          time: "сейчас", initials: initials, avatarTint: .accent, isPersonal: true,
                                          order: rootOrder - 1))
        query = ""
        filter = .all
        return true
    }

    var recentPersonalConversations: [Conversation] {
        Array(conversations.filter {
            $0.isPersonal && !$0.isChild && !$0.isSpace && $0.lastMessageAt != nil
        }.sorted {
            if $0.lastMessageAt != $1.lastMessageAt { return $0.lastMessageAt! > $1.lastMessageAt! }
            return $0.id.uuidString < $1.id.uuidString
        }.prefix(5))
    }

    func spaceConversations(_ spaceID: UUID, sectionID: UUID? = nil) -> [Conversation] {
        guard conversation(spaceID)?.isSpace == true else { return [] }
        return conversations.filter {
            $0.parentSpaceID == spaceID && $0.sectionID == sectionID
        }.sorted {
            if $0.order != $1.order { return $0.order < $1.order }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    func sectionUnreadCount(_ spaceID: UUID, sectionID: UUID) -> Int {
        spaceConversations(spaceID, sectionID: sectionID).reduce(0) { $0 + $1.unreadCount }
    }

    func sectionMentionCount(_ spaceID: UUID, sectionID: UUID) -> Int {
        spaceConversations(spaceID, sectionID: sectionID).reduce(0) { $0 + $1.unreadMentionCount }
    }

    /// Local model update for a later message; opening, mute and read never reorder DMs.
    mutating func updateLastMessage(_ id: UUID, text: String, at date: Date) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let existing = conversation(id), !existing.isSpace,
              existing.lastMessageAt == nil || date >= existing.lastMessageAt! else { return }
        update(id) {
            $0.message = text
            $0.lastMessageAt = date
        }
    }

    private mutating func recalculateSpaceCounts() {
        let totals = Dictionary(grouping: conversations.filter(\.isChild), by: { $0.parentSpaceID! })
            .mapValues { $0.reduce(0) { $0 + $1.unreadCount } }
        let mentions = Dictionary(grouping: conversations.filter(\.isChild), by: { $0.parentSpaceID! })
            .mapValues { $0.reduce(0) { $0 + $1.unreadMentionCount } }
        for index in conversations.indices where conversations[index].isSpace {
            conversations[index].unreadCount = totals[conversations[index].id, default: 0]
            conversations[index].unreadMentionCount = mentions[conversations[index].id, default: 0]
        }
    }

    private mutating func update(_ id: UUID, change: (inout Conversation) -> Void) {
        guard let index = conversations.firstIndex(where: { $0.id == id }) else { return }
        change(&conversations[index])
    }
}

/// Stored above the navigation destination so returning preserves this space's presentation.
struct SpaceHomeState {
    private(set) var collapsedSectionIDs: Set<UUID> = []
    var workScrollID: UUID?
    var personalScrollID: UUID?
    var combinedScrollID: UUID?

    func isExpanded(_ sectionID: UUID) -> Bool { !collapsedSectionIDs.contains(sectionID) }

    mutating func toggleSection(_ sectionID: UUID) {
        if !collapsedSectionIDs.insert(sectionID).inserted { collapsedSectionIDs.remove(sectionID) }
    }
}
