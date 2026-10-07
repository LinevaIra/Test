import SwiftUI

struct ActivitiesView: View {
    @Binding var state: ChatListState
    @Binding var presentation: ActivitiesPresentation
    let onOpen: (AppRoute) -> Void
    private let coordinate = "activities.list"

    var body: some View {
        RestoringSpaceList(scrollID: $presentation.scrollID, coordinate: coordinate) {
            ForEach(ActivityGroup.allCases) { group in
                Section {
                    if !presentation.collapsed.contains(group) { rows(group) }
                } header: { heading(group) }
                .textCase(nil)
            }
        }
        .background(.white)
        .modifier(AppScreenHeader(title: "Активности"))
    }

    private func heading(_ group: ActivityGroup) -> some View {
        Button { presentation.toggle(group) } label: {
            HStack(spacing: 8) {
                Text(group.rawValue).font(.headline).foregroundStyle(ChatTheme.primaryText)
                Spacer()
                Image(systemName: presentation.collapsed.contains(group) ? "chevron.right" : "chevron.down")
                    .font(.caption).foregroundStyle(ChatTheme.secondaryText)
            }
            .frame(minHeight: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(presentation.collapsed.contains(group) ? "Свёрнут" : "Развёрнут")
    }

    @ViewBuilder private func rows(_ group: ActivityGroup) -> some View {
        switch group {
        case .discussions:
            if state.activity.subscribedDiscussions.isEmpty { empty("Нет подписанных обсуждений") }
            ForEach(state.activity.subscribedDiscussions) { discussion in
                discussionRow(discussion)
            }
        case .mentions:
            if state.activity.mentions.isEmpty { empty("Пока нет упоминаний") }
            ForEach(state.activity.mentions) { mention in mentionRow(mention) }
        case .personal:
            if state.recentPersonalConversations.isEmpty { empty("Личных диалогов пока нет") }
            ForEach(state.recentPersonalConversations) { conversation in
                Button { onOpen(.personalDialogue(conversation.id)) } label: {
                    ActivityRow(symbol: "bubble.left", title: conversation.title, preview: conversation.message,
                                source: "Личный диалог", at: conversation.lastMessageAt,
                                unread: conversation.unreadCount, muted: conversation.isMuted,
                                initials: conversation.initials)
                }
                .buttonStyle(.plain)
                .modifier(ActivityRowStyle(id: conversation.id, coordinate: coordinate))
                .modifier(ReadMuteActions(conversation: conversation,
                                          onRead: { state.markRead(conversation.id) },
                                          onMute: { state.toggleMuted(conversation.id) }))
            }
        case .applications:
            let events = state.activity.applications()
            if events.isEmpty { empty("Нет событий в приложениях") }
            ForEach(events) { event in
                Button {
                    onOpen(.resource(conversationID: event.resource.conversationID,
                                     resourceID: event.resource.id, sessionID: event.sessionID))
                } label: {
                    ActivityRow(symbol: event.resource.tab.symbol, title: event.resource.title,
                                preview: event.detail, source: source(event.resource.conversationID), at: event.at)
                }
                .buttonStyle(.plain)
                .modifier(ActivityRowStyle(id: event.id, coordinate: coordinate))
            }
        }
    }

    private func discussionRow(_ discussion: Discussion) -> some View {
        let last = state.activity.lastMessage(discussion.id)
        let count = state.activity.replies(discussion.id).filter(\.isUnread).count
        return Button { onOpen(.thread(discussion.id, composing: false)) } label: {
            ActivityRow(symbol: "bubble.left.and.bubble.right", title: discussion.title,
                        preview: last.map { "\($0.author): \($0.text)" } ?? "Пока нет ответов",
                        source: source(discussion.conversationID), at: last?.sentAt, unread: count)
        }
        .buttonStyle(.plain)
        .modifier(ActivityRowStyle(id: discussion.id, coordinate: coordinate))
        .modifier(ActivityActions(isDiscussion: true,
                                  onRead: { state.readDiscussion(discussion.id) },
                                  onReply: { onOpen(.thread(discussion.id, composing: true)) },
                                  onUnsubscribe: { state.activity.unsubscribe(discussion.id) }))
    }

    private func mentionRow(_ message: ChatMessage) -> some View {
        Button { onOpen(.message(conversationID: message.conversationID, messageID: message.id, reply: false)) } label: {
            ActivityRow(symbol: "at", title: message.author, preview: message.text,
                        source: source(message.conversationID), at: message.sentAt,
                        unread: message.isUnread ? 1 : 0)
        }
        .buttonStyle(.plain)
        .modifier(ActivityRowStyle(id: message.id, coordinate: coordinate))
        .modifier(ActivityActions(isDiscussion: false,
                                  onRead: { state.readMention(message.id) },
                                  onReply: { onOpen(.message(conversationID: message.conversationID, messageID: message.id, reply: true)) },
                                  onUnsubscribe: {}))
    }

    private func source(_ id: UUID) -> String {
        guard let conversation = state.conversation(id) else { return "Источник недоступен" }
        if conversation.isPersonal { return "Личный диалог · \(conversation.title)" }
        return [conversation.parentSpaceID.flatMap { state.conversation($0)?.title }, conversation.section,
                conversation.title].compactMap { $0 }.joined(separator: " / ")
    }

    private func empty(_ text: String) -> some View {
        Text(text).font(.subheadline).foregroundStyle(ChatTheme.secondaryText).padding(.vertical, 12)
    }
}

private struct ActivityRow: View {
    let symbol: String
    let title: String
    let preview: String
    let source: String
    var at: Date? = nil
    var unread = 0
    var muted = false
    var initials: String? = nil
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol).font(.system(size: 22, weight: .regular))
                .foregroundStyle(ChatTheme.accent).frame(width: 44, height: 44)
                .background(ChatTheme.accentBackground, in: Circle()).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(title).font(.body.weight(.semibold)).foregroundStyle(ChatTheme.primaryText)
                        .lineLimit(typeSize.isAccessibilitySize ? nil : 2)
                    Spacer(minLength: 0)
                    if let at, !typeSize.isAccessibilitySize {
                        Text(at, formatter: ActivityDate.formatter).font(.caption2)
                            .foregroundStyle(ChatTheme.secondaryText).fixedSize()
                    }
                }
                Text(preview).font(.subheadline).foregroundStyle(symbol == "at" ? ChatTheme.accent : ChatTheme.secondaryText)
                    .lineLimit(typeSize.isAccessibilitySize ? nil : 2)
                HStack(spacing: 5) {
                    if let initials { InitialAvatar(initials: initials, size: 20) }
                    Text(source).font(.caption).foregroundStyle(ChatTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack {
                    if let at, typeSize.isAccessibilitySize {
                        Text(at, formatter: ActivityDate.formatter).font(.caption2).foregroundStyle(ChatTheme.secondaryText)
                    }
                    Spacer()
                    UnreadBadge(count: unread, muted: muted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
        .alignmentGuide(.listRowSeparatorLeading) { _ in 54 }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([accessibleType, title, preview, source,
                             at.map { ActivityDate.formatter.string(from: $0) } ?? "",
                             unread > 0 ? "Непрочитанных: \(unread)" : "",
                             muted ? "Без звука" : ""].filter { !$0.isEmpty }.joined(separator: ". "))
    }
    private var accessibleType: String {
        switch symbol {
        case "at": return "Упоминание"
        case "video": return "Голосовая комната"
        case "note.text": return "Заметка"
        case "rectangle.split.3x1": return "Доска"
        case "bubble.left": return "Личная беседа"
        default: return "Обсуждение"
        }
    }
}

private struct ActivityRowStyle: ViewModifier {
    let id: UUID
    let coordinate: String
    func body(content: Content) -> some View {
        content.id(id)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowBackground(Color.white).listRowSeparatorTint(ChatTheme.separator)
            .modifier(VisibleSpaceRow(id: id, coordinate: coordinate))
    }
}

private struct ActivityActions: ViewModifier {
    let isDiscussion: Bool
    let onRead: () -> Void
    let onReply: () -> Void
    let onUnsubscribe: () -> Void
    func body(content: Content) -> some View {
        content
            .contextMenu {
                Button("Отметить прочитанным", systemImage: "checkmark.circle", action: onRead)
                Button(isDiscussion ? "Написать сообщение" : "Ответить", systemImage: "arrowshape.turn.up.left", action: onReply)
                if isDiscussion { Button("Отписаться", systemImage: "minus.circle", action: onUnsubscribe) }
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button("Прочитано", systemImage: "checkmark", action: onRead).tint(ChatTheme.accent)
                if isDiscussion { Button("Отписаться", systemImage: "minus.circle", action: onUnsubscribe).tint(.gray) }
            }
            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                Button("Ответить", systemImage: "arrowshape.turn.up.left", action: onReply).tint(ChatTheme.accent)
            }
            .accessibilityActions {
                Button("Отметить прочитанным", action: onRead)
                Button(isDiscussion ? "Написать сообщение" : "Ответить", action: onReply)
                if isDiscussion { Button("Отписаться", action: onUnsubscribe) }
            }
    }
}

private enum ActivityDate {
    static let formatter: DateFormatter = {
        let value = DateFormatter()
        value.locale = Locale(identifier: "ru_RU")
        value.timeZone = TimeZone(identifier: "Europe/Moscow")
        value.dateFormat = "d MMM, HH:mm"
        return value
    }()
}
