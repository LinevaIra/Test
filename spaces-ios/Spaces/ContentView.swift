import SwiftUI

struct ContentView: View {
    @State private var state = ChatListState()
    @State private var isCreatingChat = false
    @State private var newChatName = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterBar
                conversationList
            }
            .background(.white)
            .navigationTitle("Чаты")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.white, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .searchable(text: $state.query, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Поиск чатов и пространств")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button {
                            state.markAllRead()
                        } label: {
                            Label("Прочитать всё", systemImage: "checkmark.circle")
                        }
                        Button {
                            state.restore()
                        } label: {
                            Label("Восстановить список", systemImage: "arrow.counterclockwise")
                        }
                    } label: {
                        Text("Править")
                    }
                    .accessibilityHint("Действия со списком чатов")
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
                Button("Отмена", role: .cancel) { newChatName = "" }
                Button("Создать") { state.createChat(named: newChatName) }
                    .disabled(newChatName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .frame(maxWidth: 860)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ChatTheme.searchBackground)
        .tint(ChatTheme.accent)
        .preferredColorScheme(.light)
    }

    private var conversationList: some View {
        List {
            ForEach(state.visibleConversations) { conversation in
                ConversationRow(conversation: conversation)
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                    .listRowBackground(Color.white)
                    .listRowSeparatorTint(ChatTheme.separator)
                    .contextMenu {
                        Button {
                            state.markRead(conversation.id)
                        } label: {
                            Label("Отметить прочитанным", systemImage: "checkmark.circle")
                        }
                        Button {
                            state.togglePinned(conversation.id)
                        } label: {
                            Label(conversation.isPinned ? "Открепить" : "Закрепить",
                                  systemImage: conversation.isPinned ? "pin.slash" : "pin")
                        }
                        Button {
                            state.toggleMuted(conversation.id)
                        } label: {
                            Label(conversation.isMuted ? "Включить звук" : "Без звука",
                                  systemImage: conversation.isMuted ? "bell" : "bell.slash")
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button {
                            state.markRead(conversation.id)
                        } label: {
                            Label("Прочитано", systemImage: "checkmark")
                        }
                        .tint(ChatTheme.accent)
                        Button {
                            state.toggleMuted(conversation.id)
                        } label: {
                            Label(conversation.isMuted ? "Включить звук" : "Без звука",
                                  systemImage: conversation.isMuted ? "bell" : "bell.slash")
                        }
                        .tint(ChatTheme.secondaryText)
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button {
                            state.togglePinned(conversation.id)
                        } label: {
                            Label(conversation.isPinned ? "Открепить" : "Закрепить",
                                  systemImage: conversation.isPinned ? "pin.slash" : "pin")
                        }
                        .tint(ChatTheme.accent)
                    }
                    .accessibilityAction(named: Text("Отметить прочитанным")) {
                        state.markRead(conversation.id)
                    }
                    .accessibilityAction(named: Text(conversation.isPinned ? "Открепить" : "Закрепить")) {
                        state.togglePinned(conversation.id)
                    }
                    .accessibilityAction(named: Text(conversation.isMuted ? "Включить звук" : "Без звука")) {
                        state.toggleMuted(conversation.id)
                    }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .overlay {
            if state.visibleConversations.isEmpty {
                ContentUnavailableView {
                    Label("Чаты не найдены", systemImage: "bubble.left.and.bubble.right")
                } description: {
                    Text("Попробуйте другой запрос или выберите «Все».")
                } actions: {
                    Button("Показать все чаты") {
                        state.query = ""
                        state.filter = .all
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ChatFilter.allCases) { filter in
                    filterButton(filter)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .fixedSize(horizontal: false, vertical: true)
        .background(.white)
        .overlay(alignment: .bottom) {
            Rectangle().fill(ChatTheme.separator).frame(height: 0.5)
        }
    }

    private func filterButton(_ filter: ChatFilter) -> some View {
        let isSelected = state.filter == filter
        return Button {
            state.filter = filter
        } label: {
            HStack(spacing: 6) {
                Text(filter.rawValue)
                if filter == .unread {
                    Text("\(state.unreadConversationCount)")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isSelected ? ChatTheme.accent.opacity(0.12) : Color.black.opacity(0.04),
                                    in: Capsule())
                }
            }
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: true)
            .foregroundStyle(isSelected ? ChatTheme.accent : ChatTheme.secondaryText)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(minHeight: 44)
            .background(isSelected ? ChatTheme.accentBackground : Color.clear, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(filter.rawValue)
        .accessibilityValue(filter == .unread ? "Непрочитанных чатов: \(state.unreadConversationCount)" : "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview("iPhone") {
    ContentView().frame(width: 393, height: 852)
}

#Preview("iPhone — альбомная ориентация") {
    ContentView().frame(width: 852, height: 393)
}

#Preview("iPad") {
    ContentView().frame(width: 1024, height: 768)
}

#Preview("iPad — узкое окно") {
    ContentView().frame(width: 375, height: 1024)
}

#Preview("Крупный шрифт") {
    ContentView()
        .environment(\.dynamicTypeSize, .accessibility3)
        .frame(width: 393, height: 852)
}
