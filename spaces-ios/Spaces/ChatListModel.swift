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
    let title: String
    let announcementChannel: SpaceChannel
    let sections: [SpaceSection]

    var sectionSummary: String {
        sections.map(\.title).joined(separator: " · ")
    }

    var searchTerms: [String] {
        [title, announcementChannel.title, announcementChannel.purpose]
            + sections.flatMap { section in
                [section.title] + section.channels.map(\.title)
            }
    }

    static let ether = ProductSpace(
        title: "Проект Эфир",
        announcementChannel: SpaceChannel(title: "#general", purpose: "Важные объявления", visibility: .public),
        sections: ["Чат", "Почта", "ВКС"].map { title in
            SpaceSection(title: title, channels: ["РО", "Разработка", "QA"].map {
                SpaceChannel(title: $0, purpose: "Приватный канал", visibility: .private)
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
    let isGroup: Bool
    let space: ProductSpace?
    var unreadCount: Int
    var isPinned: Bool
    var isMuted: Bool
    let order: Int

    var isSpace: Bool { space != nil }

    init(id: UUID = UUID(), title: String, sender: String? = nil, message: String,
         time: String, initials: String, avatarTint: AvatarTint, isGroup: Bool = false,
         space: ProductSpace? = nil, unreadCount: Int = 0, isPinned: Bool = false,
         isMuted: Bool = false, order: Int) {
        self.id = id
        self.title = title
        self.sender = sender
        self.message = message
        self.time = time
        self.initials = initials
        self.avatarTint = avatarTint
        self.isGroup = isGroup
        self.space = space
        self.unreadCount = unreadCount
        self.isPinned = isPinned
        self.isMuted = isMuted
        self.order = order
    }

    func matches(_ query: String) -> Bool {
        let terms = [title, sender ?? "", message] + (space?.searchTerms ?? [])
        return query.isEmpty || terms.contains { $0.localizedCaseInsensitiveContains(query) }
    }

    static let samples: [Conversation] = [
        Conversation(title: ProductSpace.ether.title, sender: "#general",
                     message: "Релиз запланирован на пятницу", time: "12:42", initials: "Э",
                     avatarTint: .accent, space: .ether, unreadCount: 12, isPinned: true, order: 0),
        Conversation(title: "Анна Смирнова", message: "Отлично, тогда до встречи!",
                     time: "12:38", initials: "АС", avatarTint: .orange, unreadCount: 2, order: 1),
        Conversation(title: "Команда продукта", sender: "Михаил", message: "Собрал заметки после встречи",
                     time: "12:21", initials: "", avatarTint: .teal, isGroup: true, unreadCount: 5, order: 2),
        Conversation(title: "Алексей", sender: "Вы", message: "Спасибо, посмотрю сегодня",
                     time: "11:54", initials: "АЛ", avatarTint: .blue, order: 3),
        Conversation(title: "Мария Козлова", message: "Отправила тебе фотографии",
                     time: "10:46", initials: "МК", avatarTint: .pink, order: 4),
        Conversation(title: "Выходные", sender: "Денис", message: "Кто идёт на прогулку?",
                     time: "вчера", initials: "", avatarTint: .teal, isGroup: true,
                     unreadCount: 8, isMuted: true, order: 5),
        Conversation(title: "Дмитрий", sender: "Вы", message: "Договорились 👍",
                     time: "вчера", initials: "ДМ", avatarTint: .purple, order: 6),
        Conversation(title: "Обсуждение релиза", sender: "Ольга", message: "Проверим финальный список задач",
                     time: "вчера", initials: "", avatarTint: .orange, isGroup: true, order: 7)
    ]
}

/// State shared by all window sizes. Resizing never replaces the demo data.
struct ChatListState {
    private(set) var conversations: [Conversation] = Conversation.samples
    var query = ""
    var filter: ChatFilter = .all

    var unreadConversationCount: Int {
        conversations.filter { $0.unreadCount > 0 }.count
    }

    var visibleConversations: [Conversation] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return conversations.filter { conversation in
            let matchesFilter: Bool
            switch filter {
            case .all: matchesFilter = true
            case .unread: matchesFilter = conversation.unreadCount > 0
            case .spaces: matchesFilter = conversation.isSpace
            }
            return matchesFilter && conversation.matches(trimmedQuery)
        }.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
            return lhs.order < rhs.order
        }
    }

    mutating func markRead(_ id: UUID) {
        update(id) { $0.unreadCount = 0 }
    }

    mutating func toggleMuted(_ id: UUID) {
        update(id) { $0.isMuted.toggle() }
    }

    mutating func togglePinned(_ id: UUID) {
        update(id) { $0.isPinned.toggle() }
    }

    mutating func markAllRead() {
        for index in conversations.indices { conversations[index].unreadCount = 0 }
    }

    mutating func restore() {
        conversations = Conversation.samples
        query = ""
        filter = .all
    }

    @discardableResult
    mutating func createChat(named name: String) -> Bool {
        let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return false }
        let initials = title.split(whereSeparator: \.isWhitespace)
            .prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
        conversations.append(Conversation(title: title, message: "Пока нет сообщений",
                                          time: "сейчас", initials: initials, avatarTint: .accent,
                                          order: (conversations.map(\.order).min() ?? 0) - 1))
        query = ""
        filter = .all
        return true
    }

    private mutating func update(_ id: UUID, change: (inout Conversation) -> Void) {
        guard let index = conversations.firstIndex(where: { $0.id == id }) else { return }
        change(&conversations[index])
    }
}
