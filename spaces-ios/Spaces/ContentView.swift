import SwiftUI

struct ContentView: View {
    @State private var state = ChatListState()
    @State private var navigation = AppNavigationState()
    @State private var spacePresentations: [UUID: SpaceHomeState] = [:]
    @State private var dialoguePresentations: [String: DialoguePresentation] = [:]
    @State private var activitiesPresentation = ActivitiesPresentation()
    @State private var isCreatingChat = false
    @State private var newChatName = ""

    var body: some View {
        NavigationStack(path: $navigation.path) {
            VStack(spacing: 0) {
                filterBar
                conversationList
            }
            .background(.white)
            .navigationTitle("Чаты")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar)
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
                            spacePresentations = [:]
                            dialoguePresentations = [:]
                            activitiesPresentation = ActivitiesPresentation()
                        } label: {
                            Label("Восстановить список", systemImage: "arrow.counterclockwise")
                        }
                    } label: {
                        Text("Править")
                    }
                    .accessibilityHint("Действия со списком чатов")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 8) {
                        ActivitiesButton { navigation.openActivities() }

                        Button {
                            newChatName = ""
                            isCreatingChat = true
                        } label: {
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: 20, weight: .regular))
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .accessibilityLabel("Создать чат")
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationDestination(for: AppRoute.self) { route in
                destination(for: route)
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
                conversationEntry(conversation)
                    .listRowInsets(EdgeInsets(top: 8, leading: conversation.isChild ? 36 : 16,
                                              bottom: 8, trailing: 16))
                    .listRowBackground(Color.white)
                    .listRowSeparatorTint(ChatTheme.separator)
                    .contextMenu {
                        Button {
                            state.markRead(conversation.id)
                        } label: {
                            Label("Отметить прочитанным", systemImage: "checkmark.circle")
                        }
                        if !conversation.isChild {
                            Button {
                                state.togglePinned(conversation.id)
                            } label: {
                                Label(conversation.isPinned ? "Открепить" : "Закрепить",
                                      systemImage: conversation.isPinned ? "pin.slash" : "pin")
                            }
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
                        if !conversation.isChild {
                            Button {
                                state.togglePinned(conversation.id)
                            } label: {
                                Label(conversation.isPinned ? "Открепить" : "Закрепить",
                                      systemImage: conversation.isPinned ? "pin.slash" : "pin")
                            }
                            .tint(ChatTheme.accent)
                        }
                    }
                    .accessibilityActions {
                        Button("Отметить прочитанным") { state.markRead(conversation.id) }
                        if !conversation.isChild {
                            Button(conversation.isPinned ? "Открепить" : "Закрепить") {
                                state.togglePinned(conversation.id)
                            }
                        }
                        Button(conversation.isMuted ? "Включить звук" : "Без звука") {
                            state.toggleMuted(conversation.id)
                        }
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

    @ViewBuilder
    private func conversationEntry(_ conversation: Conversation) -> some View {
        let parentTitle = conversation.parentSpaceID.flatMap { state.conversation($0)?.title }
        if let route = state.route(for: conversation) {
            Button {
                navigation.open(route)
            } label: {
                ConversationRow(conversation: conversation, parentSpaceTitle: parentTitle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(conversation.isSpace ? "Открыть пространство" : "Открыть диалог")
        } else {
            ConversationRow(conversation: conversation)
        }
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case .space(let id):
            SpaceHomeView(spaceID: id, state: $state, presentation: spacePresentation(for: id),
                          onOpen: { conversation in
                              if let route = state.route(for: conversation) { navigation.open(route) }
                          }, onActivities: { navigation.openActivities() })
        case .dialogue(let spaceID, let conversationID, let kind):
            if let conversation = state.conversation(conversationID),
               conversation.parentSpaceID == spaceID, conversation.kind == kind {
                dialogue(conversationID)
            } else { unavailable }
        case .personalDialogue(let id), .conversation(let id):
            if state.conversation(id) != nil { dialogue(id) } else { unavailable }
        case .message(let conversationID, let messageID, let reply):
            if let message = state.activity.message(messageID), message.conversationID == conversationID {
                DialogueView(conversationID: conversationID, state: $state,
                             presentation: dialoguePresentation(message.threadID.map { "thread.\($0)" } ?? "message.\(messageID)"),
                             focusedMessageID: messageID, composing: reply,
                             onOpen: { navigation.open($0) }, onActivities: { navigation.openActivities() })
            } else { unavailable }
        case .thread(let id, let composing):
            if let thread = state.activity.discussion(id) {
                DialogueView(conversationID: thread.conversationID, state: $state,
                             presentation: dialoguePresentation("thread.\(id)"), initialThreadID: id,
                             composing: composing, onOpen: { navigation.open($0) },
                             onActivities: { navigation.openActivities() })
            } else { unavailable }
        case .resource(let conversationID, let resourceID, let sessionID):
            if let resource = state.activity.resource(resourceID), resource.isAccessible,
               resource.conversationID == conversationID, state.conversation(conversationID) != nil,
               sessionID == nil || sessionID.flatMap({ state.activity.session($0)?.resourceID }) == resourceID {
                DialogueView(conversationID: conversationID, state: $state,
                             presentation: dialoguePresentation("conversation.\(conversationID)"),
                             focusedResourceID: resourceID, selectedSessionID: sessionID,
                             onOpen: { navigation.open($0) }, onActivities: { navigation.openActivities() })
            } else { unavailable }
        case .activities:
            ActivitiesView(state: $state, presentation: $activitiesPresentation,
                           onOpen: { navigation.open($0) })
        }
    }

    private var unavailable: some View {
        ContentUnavailableView("Ресурс недоступен", systemImage: "exclamationmark.bubble")
            .modifier(AppScreenHeader(title: "Недоступно", onActivities: { navigation.openActivities() }))
    }

    private func dialogue(_ id: UUID) -> some View {
        DialogueView(conversationID: id, state: $state,
                     presentation: dialoguePresentation("conversation.\(id)"),
                     onOpen: { navigation.open($0) }, onActivities: { navigation.openActivities() })
    }

    private func dialoguePresentation(_ key: String) -> Binding<DialoguePresentation> {
        Binding(get: { dialoguePresentations[key, default: DialoguePresentation()] },
                set: { dialoguePresentations[key] = $0 })
    }

    private func spacePresentation(for id: UUID) -> Binding<SpaceHomeState> {
        Binding(get: { spacePresentations[id, default: SpaceHomeState()] },
                set: { spacePresentations[id] = $0 })
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

struct ActivitiesButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ActivityBubblesIcon()
                .foregroundStyle(ChatTheme.accent)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Активности")
        .accessibilityHint("Открыть экран активностей")
    }
}

/// Vector drawing matching R4's silhouette, with no bitmap, badge or animation.
private struct ActivityBubblesIcon: View {
    private let stroke = StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)

    var body: some View {
        ZStack {
            ActivityBubbleShape()
                .stroke(style: stroke)
                .scaleEffect(x: -1, y: 1)
                .frame(width: 17, height: 17)
                .offset(x: 4, y: 4)
            ActivityBubbleShape()
                .fill(.white)
                .overlay { ActivityBubbleShape().stroke(style: stroke) }
                .frame(width: 20, height: 18)
                .overlay(alignment: .center) {
                    HStack(spacing: 2) {
                        ForEach(0..<3) { _ in Circle().frame(width: 2, height: 2) }
                    }
                    .offset(y: -1)
                }
                .offset(x: -2, y: -2)
        }
        .frame(width: 24, height: 24)
        .accessibilityHidden(true)
    }
}

private struct ActivityBubbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }
        var path = Path()
        path.move(to: point(0.5, 0.04))
        path.addCurve(to: point(0.96, 0.44), control1: point(0.77, 0.04), control2: point(0.96, 0.18))
        path.addCurve(to: point(0.5, 0.84), control1: point(0.96, 0.7), control2: point(0.77, 0.84))
        path.addQuadCurve(to: point(0.31, 0.81), control: point(0.4, 0.84))
        path.addLine(to: point(0.04, 0.96))
        path.addLine(to: point(0.13, 0.67))
        path.addCurve(to: point(0.04, 0.44), control1: point(0.07, 0.61), control2: point(0.04, 0.53))
        path.addCurve(to: point(0.5, 0.04), control1: point(0.04, 0.18), control2: point(0.23, 0.04))
        path.closeSubpath()
        return path
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
