import SwiftUI

struct DialogueView: View {
    let conversationID: UUID
    @Binding var state: ChatListState
    @Binding var presentation: DialoguePresentation
    var initialThreadID: UUID? = nil
    var focusedMessageID: UUID? = nil
    var composing = false
    var focusedResourceID: UUID? = nil
    var selectedSessionID: UUID? = nil
    let onOpen: (AppRoute) -> Void
    let onActivities: () -> Void
    @State private var replyTargetID: UUID?
    @State private var createdThreadID: UUID?
    @FocusState private var inputFocused: Bool

    private var conversation: Conversation? { state.conversation(conversationID) }
    private var threadID: UUID? {
        createdThreadID ?? initialThreadID ?? focusedMessageID.flatMap { state.activity.message($0)?.threadID }
    }
    private var discussion: Discussion? { threadID.flatMap { state.activity.discussion($0) } }
    private var resources: [TeamResource] { state.activity.resources.filter { $0.conversationID == conversationID } }
    private var showsTabs: Bool { (conversation?.hasTeamResources == true || !resources.isEmpty) && threadID == nil }
    private var messages: [ChatMessage] {
        if let threadID, let root = discussion.flatMap({ state.activity.message($0.rootMessageID) }) {
            return [root] + state.activity.replies(threadID)
        }
        return state.activity.feed(conversationID)
    }
    private var canCompose: Bool {
        threadID != nil || replyTargetID != nil || conversation?.kind == .chat
    }
    private var title: String {
        conversation?.parentSpaceID.flatMap { state.conversation($0)?.title } ?? conversation?.title ?? "Диалог"
    }
    private var subtitle: String? {
        if let discussion { return "Обсуждение · \(discussion.title)" }
        guard let conversation, conversation.isChild else { return nil }
        return "\(conversation.title) · \(conversation.kind.rawValue)"
    }

    var body: some View {
        VStack(spacing: 0) {
            if showsTabs { tabs }
            if showsTabs && presentation.tab != .messages {
                TeamResourcesView(conversationID: conversationID, state: $state, presentation: $presentation,
                                  selectedSessionID: selectedSessionID)
            } else {
                messageFeed
                if canCompose { composer }
            }
        }
        .background(ChatTheme.searchBackground)
        .modifier(AppScreenHeader(title: title, subtitle: subtitle, onActivities: onActivities))
        .accessibilityIdentifier("dialogue.\(conversationID)")
        .task {
            if let resourceID = focusedResourceID, let resource = state.activity.resource(resourceID) {
                presentation.tab = resource.tab
                if resource.tab == .notes { presentation.selectedNoteID = resource.id }
            } else if focusedMessageID != nil || initialThreadID != nil { presentation.tab = .messages }
            if composing { replyTargetID = focusedMessageID; inputFocused = true }
        }
    }

    private var tabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(DialogueTab.allCases) { tab in
                    Button { presentation.tab = tab; inputFocused = false } label: {
                        Label(tab.rawValue, systemImage: tab.symbol)
                            .font(.subheadline.weight(.medium)).fixedSize()
                            .foregroundStyle(presentation.tab == tab ? ChatTheme.accent : ChatTheme.secondaryText)
                            .padding(.horizontal, 12).frame(minHeight: 44)
                            .overlay(alignment: .bottom) {
                                if presentation.tab == tab { ChatTheme.accent.frame(height: 2) }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(presentation.tab == tab ? .isSelected : [])
                }
            }
        }
        .background(.white)
    }

    private var messageFeed: some View {
        GeometryReader { viewport in
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    if messages.isEmpty {
                        Text("Сообщений пока нет").foregroundStyle(ChatTheme.secondaryText).padding(32)
                    }
                    ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                        if index == 0 || !Calendar.current.isDate(message.sentAt, inSameDayAs: messages[index - 1].sentAt) {
                            Text(message.sentAt, format: .dateTime.day().month().year())
                                .font(.caption).foregroundStyle(ChatTheme.secondaryText)
                                .padding(.horizontal, 10).padding(.vertical, 4)
                                .background(.white.opacity(0.8), in: Capsule())
                        }
                        if message.id == messages.first(where: \.isUnread)?.id {
                            Text("Непрочитанные сообщения").font(.caption.weight(.medium))
                                .foregroundStyle(ChatTheme.accent).frame(maxWidth: .infinity)
                                .padding(6).background(ChatTheme.accentBackground)
                        }
                        messageBubble(message, width: viewport.size.width - 24)
                            .id(message.id)
                    }
                }
                .scrollTargetLayout()
                .padding(12)
            }
            .scrollPosition(id: $presentation.scrollID)
            .scrollDismissesKeyboard(.interactively)
            .task(id: threadID) {
                await Task.yield()
                let target = createdThreadID != nil ? messages.last?.id : focusedMessageID ?? presentation.scrollID ?? messages.first(where: \.isUnread)?.id ?? messages.last?.id
                if let target { proxy.scrollTo(target, anchor: focusedMessageID == nil && target == messages.last?.id ? .bottom : .top) }
            }
            .onChange(of: messages.last?.id) { _, id in
                if let id, messages.last?.isOutgoing == true { withAnimation { proxy.scrollTo(id, anchor: .bottom) } }
            }
        }
        }
    }

    private func messageBubble(_ message: ChatMessage, width: CGFloat) -> some View {
            HStack {
                if message.isOutgoing { Spacer(minLength: 0) }
                VStack(alignment: .leading, spacing: 5) {
                    if conversation?.isPersonal == false && !message.isOutgoing {
                        Text(message.author).font(.caption.weight(.semibold)).foregroundStyle(ChatTheme.accent)
                    }
                    if let replyID = message.replyToMessageID, let quoted = state.activity.message(replyID) {
                        Text("↪ \(quoted.author): \(quoted.text)").font(.caption)
                            .foregroundStyle(ChatTheme.secondaryText).lineLimit(2)
                    }
                    Text(message.text).foregroundStyle(message.mentionsMe ? ChatTheme.accent : ChatTheme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Spacer(minLength: 0)
                        Text(message.sentAt, formatter: MessageTime.formatter).font(.caption2)
                            .foregroundStyle(ChatTheme.secondaryText)
                    }
                    if threadID == nil, let thread = state.activity.discussions.first(where: { $0.rootMessageID == message.id }) {
                        Button {
                            onOpen(.thread(thread.id, composing: false))
                        } label: {
                            Label("Ответы: \(state.activity.replies(thread.id).count)", systemImage: "bubble.left.and.bubble.right")
                                .font(.caption.weight(.medium))
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(10)
                .frame(maxWidth: max(1, width * 0.8), alignment: .leading)
                .background(message.isOutgoing ? ChatTheme.accentBackground : Color.white,
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    if focusedMessageID == message.id {
                        RoundedRectangle(cornerRadius: 16).stroke(ChatTheme.accent.opacity(0.5), lineWidth: 1)
                    }
                }
                .contextMenu {
                    Button("Ответить", systemImage: "arrowshape.turn.up.left") {
                        replyTargetID = message.id; inputFocused = true
                    }
                    Button("Отметить прочитанным", systemImage: "checkmark") { state.readMention(message.id) }
                }
                if !message.isOutgoing { Spacer(minLength: 0) }
            }
    }

    private var composer: some View {
        VStack(spacing: 4) {
            if let replyID = replyTargetID, let target = state.activity.message(replyID) {
                HStack {
                    Text("Ответ: \(target.text)").font(.caption).lineLimit(2).foregroundStyle(ChatTheme.secondaryText)
                    Spacer()
                    Button { replyTargetID = nil } label: { Image(systemName: "xmark.circle") }
                        .frame(width: 44, height: 44).accessibilityLabel("Отменить ответ")
                }
            }
            HStack(alignment: .bottom, spacing: 8) {
                TextField(threadID == nil ? "Сообщение" : "Ответить в обсуждение", text: $presentation.draft, axis: .vertical)
                    .lineLimit(1...6).focused($inputFocused).padding(10)
                    .background(ChatTheme.searchBackground, in: RoundedRectangle(cornerRadius: 20))
                Button(action: send) {
                    Image(systemName: "arrow.up.circle.fill").font(.system(size: 32))
                        .frame(width: 44, height: 44)
                }
                .disabled(presentation.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("Отправить сообщение")
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8).background(.white)
    }

    private func send() {
        guard let conversation, !presentation.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        var destinationThread = threadID
        if let replyID = replyTargetID, !conversation.isPersonal, destinationThread == nil {
            destinationThread = state.activity.ensureDiscussion(for: replyID)
            createdThreadID = destinationThread
        }
        if state.sendMessage(presentation.draft, conversationID: conversationID, threadID: destinationThread, replyTo: replyTargetID) != nil {
            presentation.draft = ""; replyTargetID = nil
        }
    }
}

private enum MessageTime {
    static let formatter: DateFormatter = {
        let value = DateFormatter(); value.locale = Locale(identifier: "ru_RU")
        value.timeZone = TimeZone(identifier: "Europe/Moscow"); value.dateFormat = "HH:mm"
        return value
    }()
}
