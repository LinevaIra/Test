import Foundation

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

struct SpaceSection: Equatable {
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
        sections: ["Чат", "Почта", "ВКС"].map { title in
            SpaceSection(title: title, channels: ["РО", "Разработка", "QA"].map {
                SpaceChannel(title: $0, purpose: title == "Чат" ? "Приватный чат" : "Приватный канал",
                             visibility: .private)
            })
        }
    )
}

struct Conversation: Identifiable, Equatable {
    let id: UUID
    let title: String
    let sender: String?
    let message: String
    let time: String
    let initials: String
    let avatarTint: AvatarTint
    let space: ProductSpace?
    let parentSpaceID: UUID?
    let kind: ConversationKind
    let section: String?
    var unreadCount: Int
    var isPinned: Bool
    var isMuted: Bool
    let order: Int

    var isSpace: Bool { space != nil }
    var isChild: Bool { parentSpaceID != nil }

    init(id: UUID = UUID(), title: String, sender: String? = nil, message: String,
         time: String, initials: String, avatarTint: AvatarTint, space: ProductSpace? = nil,
         parentSpaceID: UUID? = nil, kind: ConversationKind = .chat, section: String? = nil,
         unreadCount: Int = 0, isPinned: Bool = false, isMuted: Bool = false, order: Int) {
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
        Conversation(title: "Анна Смирнова", message: "Отлично, тогда до встречи!",
                     time: "12:38", initials: "АС", avatarTint: .orange, unreadCount: 2, order: 1),
        Conversation(title: "Команда продукта", sender: "Михаил", message: "Собрал заметки после встречи",
                     time: "12:21", initials: "КП", avatarTint: .teal, unreadCount: 5, order: 2),
        Conversation(title: "Алексей", sender: "Вы", message: "Спасибо, посмотрю сегодня",
                     time: "11:54", initials: "А", avatarTint: .blue, order: 3),
        Conversation(title: "Мария Козлова", message: "Отправила тебе фотографии",
                     time: "10:46", initials: "МК", avatarTint: .pink, order: 4),
        Conversation(title: "Выходные", sender: "Денис", message: "Кто идёт на прогулку?",
                     time: "вчера", initials: "В", avatarTint: .teal,
                     unreadCount: 8, isMuted: true, order: 5),
        Conversation(title: "Дмитрий", sender: "Вы", message: "Договорились 👍",
                     time: "вчера", initials: "Д", avatarTint: .purple, order: 6),
        Conversation(title: "Обсуждение релиза", sender: "Ольга", message: "Проверим финальный список задач",
                     time: "вчера", initials: "ОР", avatarTint: .orange, order: 7),
        Conversation(title: "#general — Важные объявления", message: "Релиз запланирован на пятницу",
                     time: "12:42", initials: "ВО", avatarTint: .accent,
                     parentSpaceID: ProductSpace.sber.id, kind: .channel, unreadCount: 3, order: 0),
        Conversation(title: "Разработка", sender: "Паша", message: "Сборка готова к проверке",
                     time: "12:35", initials: "Р", avatarTint: .teal,
                     parentSpaceID: ProductSpace.sber.id, section: "Чат", unreadCount: 5, order: 1),
        Conversation(title: "QA", sender: "Вика", message: "Регресс завершён, обновила результаты",
                     time: "12:30", initials: "QA", avatarTint: .accent,
                     parentSpaceID: ProductSpace.sber.id, section: "Чат", unreadCount: 4, order: 2)
    ]
}

/// A destination identifies a space or an exact dialogue, independently of unread state.
enum AppRoute: Hashable {
    case space(UUID)
    case dialogue(spaceID: UUID, conversationID: UUID, kind: ConversationKind)
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
        conversations.filter { !$0.isChild && $0.unreadCount > 0 }.count
    }

    var visibleConversations: [Conversation] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let roots = conversations.filter { !$0.isChild }.sorted {
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
        guard let parentID = conversation.parentSpaceID,
              self.conversation(parentID)?.isSpace == true else { return nil }
        return .dialogue(spaceID: parentID, conversationID: conversation.id, kind: conversation.kind)
    }

    mutating func markRead(_ id: UUID) {
        guard let target = conversation(id) else { return }
        for index in conversations.indices {
            if conversations[index].id == id || (target.isSpace && conversations[index].parentSpaceID == id) {
                conversations[index].unreadCount = 0
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
        for index in conversations.indices { conversations[index].unreadCount = 0 }
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
                                          time: "сейчас", initials: initials, avatarTint: .accent,
                                          order: rootOrder - 1))
        query = ""
        filter = .all
        return true
    }

    private mutating func recalculateSpaceCounts() {
        let totals = Dictionary(grouping: conversations.filter(\.isChild), by: { $0.parentSpaceID! })
            .mapValues { $0.reduce(0) { $0 + $1.unreadCount } }
        for index in conversations.indices where conversations[index].isSpace {
            conversations[index].unreadCount = totals[conversations[index].id, default: 0]
        }
    }

    private mutating func update(_ id: UUID, change: (inout Conversation) -> Void) {
        guard let index = conversations.firstIndex(where: { $0.id == id }) else { return }
        change(&conversations[index])
    }
}
