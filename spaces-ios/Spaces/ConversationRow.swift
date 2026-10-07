import SwiftUI

struct ConversationRow: View {
    let conversation: Conversation
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var scaledAvatarSize: CGFloat = 56

    private var avatarSize: CGFloat { min(scaledAvatarSize, 72) }
    private var usesLargeType: Bool { dynamicTypeSize.isAccessibilitySize }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            avatar
            VStack(alignment: .leading, spacing: 5) {
                if usesLargeType {
                    title
                    HStack(spacing: 8) {
                        time
                        Spacer(minLength: 8)
                        status
                    }
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        title
                        Spacer(minLength: 4)
                        time
                    }
                }
                if let space = conversation.space {
                    spaceMetadata(space)
                }
                HStack(alignment: .top, spacing: 8) {
                    messagePreview
                        .font(.subheadline)
                        .lineLimit(usesLargeType ? 3 : 1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if !usesLargeType { status }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .alignmentGuide(.listRowSeparatorLeading) { _ in avatarSize + 12 }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var title: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(conversation.title)
                .font(.body.weight(.semibold))
                .foregroundStyle(ChatTheme.primaryText)
                .lineLimit(usesLargeType ? 2 : 1)
                .layoutPriority(1)
            if conversation.isMuted {
                Image(systemName: "bell.slash.fill")
                    .font(.caption2)
                    .foregroundStyle(ChatTheme.secondaryText)
            }
        }
    }

    private var time: some View {
        Text(conversation.time)
            .font(.caption)
            .foregroundStyle(ChatTheme.secondaryText)
            .fixedSize(horizontal: true, vertical: true)
    }

    private func spaceMetadata(_ space: ProductSpace) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Пространство")
                .font(.caption.weight(.semibold))
                .foregroundStyle(ChatTheme.accent)
            Text(space.sectionSummary)
                .font(.caption)
                .foregroundStyle(ChatTheme.secondaryText)
                .lineLimit(usesLargeType ? 2 : 1)
        }
    }

    private var messagePreview: Text {
        let message = Text(conversation.message).foregroundColor(ChatTheme.secondaryText)
        if let sender = conversation.sender {
            return Text("\(sender): ").foregroundColor(ChatTheme.primaryText) + message
        }
        return message
    }

    @ViewBuilder
    private var status: some View {
        HStack(spacing: 6) {
            if conversation.isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption2)
                    .foregroundStyle(ChatTheme.secondaryText)
            }
            if conversation.unreadCount > 0 {
                Text("\(conversation.unreadCount)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .frame(minWidth: 24, minHeight: 24)
                    .background(conversation.isMuted ? ChatTheme.mutedBadge : ChatTheme.accent, in: Capsule())
                    .fixedSize(horizontal: true, vertical: true)
            }
        }
    }

    private var avatar: some View {
        ZStack {
            if conversation.isSpace {
                RoundedRectangle(cornerRadius: 8)
                    .fill(ChatTheme.accent.gradient)
            } else {
                Circle().fill(ChatTheme.color(conversation.avatarTint.rawValue).gradient)
            }
            if conversation.isGroup {
                Image(systemName: "person.2.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
            } else {
                Text(conversation.initials)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: avatarSize, height: avatarSize)
        .accessibilityHidden(true)
    }

    private var accessibilitySummary: String {
        var parts = [conversation.title]
        if let space = conversation.space {
            parts += ["Пространство", space.sectionSummary]
        }
        if let sender = conversation.sender { parts.append(sender) }
        parts += [conversation.message, conversation.time]
        if conversation.unreadCount > 0 {
            parts.append("Непрочитанных сообщений: \(conversation.unreadCount)")
        }
        if conversation.isPinned { parts.append("Закреплено") }
        if conversation.isMuted { parts.append("Без звука") }
        return parts.joined(separator: ". ")
    }
}
