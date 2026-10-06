import SwiftUI

struct ContentView: View {
    @State private var conversations = Conversation.samples
    @State private var searchText = ""
    @State private var filter: ChatFilter = .all
    @State private var isCreatingChat = false
    @State private var newChatName = ""

    private var visibleConversations: [Conversation] {
        conversations.filter { conversation in
            let matchesFilter = filter == .all
                || (filter == .unread && conversation.unreadCount > 0)
                || (filter == .spaces && conversation.isSpace)
            let matchesSearch = searchText.isEmpty
                || conversation.title.localizedCaseInsensitiveContains(searchText)
                || conversation.message.localizedCaseInsensitiveContains(searchText)
                || conversation.chatNames.contains { $0.localizedCaseInsensitiveContains(searchText) }
            return matchesFilter && matchesSearch
        }.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
            return lhs.order < rhs.order
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterBar
                List {
                    ForEach(visibleConversations) { conversation in
                        ConversationRow(conversation: conversation)
                            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color(uiColor: .systemBackground))
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button {
                                    update(conversation.id) { $0.unreadCount = 0 }
                                } label: {
                                    Label("Прочитано", systemImage: "checkmark")
                                }
                                .tint(.blue)
                                Button {
                                    update(conversation.id) { $0.isMuted.toggle() }
                                } label: {
                                    Label(conversation.isMuted ? "Включить звук" : "Без звука",
                                          systemImage: conversation.isMuted ? "bell" : "bell.slash")
                                }
                                .tint(.gray)
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button {
                                    update(conversation.id) { $0.isPinned.toggle() }
                                } label: {
                                    Label(conversation.isPinned ? "Открепить" : "Закрепить",
                                          systemImage: conversation.isPinned ? "pin.slash" : "pin")
                                }
                                .tint(.indigo)
                            }
                    }
                }
                .listStyle(.plain)
                .overlay {
                    if visibleConversations.isEmpty {
                        ContentUnavailableView(
                            "Чаты не найдены",
                            systemImage: "bubble.left.and.bubble.right",
                            description: Text("Попробуйте другой запрос или выберите «Все».")
                        )
                    }
                }
            }
            .navigationTitle("Чаты")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Поиск чатов и пространств")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button {
                            for index in conversations.indices {
                                conversations[index].unreadCount = 0
                            }
                        } label: {
                            Label("Прочитать всё", systemImage: "checkmark.circle")
                        }
                        Button {
                            conversations = Conversation.samples
                        } label: {
                            Label("Восстановить список", systemImage: "arrow.counterclockwise")
                        }
                    } label: {
                        Text("Править")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        newChatName = ""
                        isCreatingChat = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("Новый чат")
                }
            }
            .alert("Новый чат", isPresented: $isCreatingChat) {
                TextField("Название", text: $newChatName)
                Button("Отмена", role: .cancel) { }
                Button("Создать") { createChat() }
                    .disabled(newChatName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .tint(.blue)
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ChatFilter.allCases) { item in
                    Button {
                        filter = item
                    } label: {
                        HStack(spacing: 6) {
                            Text(item.rawValue)
                            if item == .unread {
                                Text("\(conversations.filter { $0.unreadCount > 0 }.count)")
                                    .font(.caption.weight(.semibold))
                            }
                        }
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .foregroundStyle(filter == item ? Color.blue : Color.secondary)
                        .background(filter == item ? Color.blue.opacity(0.12) : Color(uiColor: .secondarySystemBackground),
                                    in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(filter == item ? .isSelected : [])
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color(uiColor: .systemBackground))
        .overlay(alignment: .bottom) { Divider() }
    }

    private func update(_ id: UUID, change: (inout Conversation) -> Void) {
        guard let index = conversations.firstIndex(where: { $0.id == id }) else { return }
        change(&conversations[index])
    }

    private func createChat() {
        let title = newChatName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        conversations.insert(Conversation(title: title, message: "Пока нет сообщений",
                                          time: "сейчас", initials: String(title.prefix(2)).uppercased(),
                                          color: .blue, order: (conversations.map(\.order).min() ?? 0) - 1), at: 0)
        searchText = ""
        filter = .all
    }
}

private enum ChatFilter: String, CaseIterable, Identifiable {
    case all = "Все"
    case unread = "Непрочитанные"
    case spaces = "Пространства"

    var id: Self { self }
}

private struct Conversation: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let time: String
    let initials: String
    let color: Color
    var unreadCount = 0
    var isPinned = false
    var isMuted = false
    var chatNames: [String] = []
    var order: Int

    var isSpace: Bool { !chatNames.isEmpty }

    static let samples: [Conversation] = [
        Conversation(title: "Студия Север", message: "Дизайн: Макеты готовы к обсуждению",
                     time: "12:42", initials: "", color: .indigo, unreadCount: 12, isPinned: true,
                     chatNames: ["Общий", "Дизайн", "Разработка", "Релизы"], order: 0),
        Conversation(title: "Анна Смирнова", message: "Отлично, тогда до встречи!", time: "12:38",
                     initials: "АС", color: .orange, unreadCount: 2, order: 1),
        Conversation(title: "Команда продукта", message: "Михаил: Собрал заметки после встречи", time: "12:21",
                     initials: "", color: .teal, unreadCount: 5, order: 2),
        Conversation(title: "Алексей", message: "Вы: Спасибо, посмотрю сегодня", time: "11:54",
                     initials: "АЛ", color: .blue, order: 3),
        Conversation(title: "Дом на Лесной", message: "Соседи: В субботу встречаемся во дворе", time: "11:30",
                     initials: "", color: .green, unreadCount: 3, isMuted: true,
                     chatNames: ["Соседи", "Объявления", "Вопросы УК"], order: 4),
        Conversation(title: "Мария Козлова", message: "Отправила тебе фотографии", time: "10:46",
                     initials: "МК", color: .pink, order: 5),
        Conversation(title: "Выходные", message: "Денис: Кто идёт на прогулку?", time: "вчера",
                     initials: "", color: .cyan, unreadCount: 8, isMuted: true, order: 6),
        Conversation(title: "Дмитрий", message: "Вы: Договорились 👍", time: "вчера",
                     initials: "ДМ", color: .purple, order: 7)
    ]
}

private struct ConversationRow: View {
    let conversation: Conversation

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            avatar
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(conversation.title)
                        .font(.body.weight(.semibold))
                        .lineLimit(1)
                    if conversation.isMuted {
                        Image(systemName: "bell.slash.fill")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .accessibilityLabel("Без звука")
                    }
                    Spacer(minLength: 4)
                    Text(conversation.time)
                        .font(.caption)
                        .foregroundStyle(conversation.unreadCount > 0 ? Color.blue : Color.secondary)
                }
                if conversation.isSpace {
                    HStack(spacing: 5) {
                        Text("Пространство")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(conversation.color)
                        Text("· \(conversation.chatNames.count) чата")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                HStack(alignment: .top, spacing: 8) {
                    Text(conversation.message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if conversation.unreadCount > 0 {
                        Text("\(conversation.unreadCount)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(conversation.isMuted ? Color.gray : Color.blue, in: Capsule())
                            .accessibilityLabel("Непрочитанных сообщений: \(conversation.unreadCount)")
                    } else if conversation.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .accessibilityLabel("Закреплено")
                    }
                }
                if conversation.isSpace {
                    Text(conversation.chatNames.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(conversation.isSpace ? 12 : 0)
        .background {
            if conversation.isSpace {
                RoundedRectangle(cornerRadius: 16)
                    .fill(conversation.color.opacity(0.06))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(conversation.color.opacity(0.15), lineWidth: 1)
                    }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if !conversation.isSpace {
                Divider().padding(.leading, 68).offset(y: 12)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var avatar: some View {
        ZStack {
            if conversation.isSpace {
                RoundedRectangle(cornerRadius: 16)
                    .fill(conversation.color.gradient)
            } else {
                Circle().fill(conversation.color.gradient)
            }
            if conversation.isSpace || conversation.initials.isEmpty {
                Image(systemName: conversation.isSpace ? "square.grid.2x2.fill" : "person.2.fill")
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(.white)
            } else {
                Text(conversation.initials)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 56, height: 56)
        .accessibilityHidden(true)
    }
}

#Preview {
    ContentView()
}

#Preview("Тёмная тема") {
    ContentView()
        .preferredColorScheme(.dark)
}
