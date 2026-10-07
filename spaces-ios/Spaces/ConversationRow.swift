import SwiftUI
import UIKit

struct ConversationRow: View {
    let conversation: Conversation
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var scaledAvatarSize: CGFloat = 48

    private var avatarSize: CGFloat { min(scaledAvatarSize, 64) }
    private var usesLargeType: Bool { dynamicTypeSize.isAccessibilitySize }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            avatar
            VStack(alignment: .leading, spacing: 3) {
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
        .alignmentGuide(.listRowSeparatorLeading) { _ in avatarSize + 10 }
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
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 4) {
                spaceLabel
                Text("·").foregroundStyle(ChatTheme.secondaryText)
                Text(space.sectionSummary).foregroundStyle(ChatTheme.secondaryText)
            }
            .font(.caption)
            .fixedSize(horizontal: true, vertical: true)

            VStack(alignment: .leading, spacing: 2) {
                spaceLabel
                Text(space.sectionSummary)
                    .font(.caption)
                    .foregroundStyle(ChatTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var spaceLabel: some View {
        Text("Пространство")
            .font(.caption.weight(.semibold))
            .foregroundStyle(ChatTheme.accent)
            .fixedSize(horizontal: false, vertical: true)
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
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .frame(minWidth: 20, minHeight: 20)
                    .background(conversation.isMuted ? ChatTheme.mutedBadge : ChatTheme.accent, in: Capsule())
                    .fixedSize(horizontal: true, vertical: true)
            }
        }
    }

    private var avatar: some View {
        Group {
            if conversation.isSpace {
                avatarArtwork
                    .clipShape(RoundedRectangle(cornerRadius: avatarSize * 14 / 48, style: .continuous))
            } else {
                avatarArtwork.clipShape(Circle())
            }
        }
        .frame(width: avatarSize, height: avatarSize)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var avatarArtwork: some View {
        if let asset = conversation.corporateAvatar, let image = UIImage(named: asset.rawValue) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: avatarSize, height: avatarSize)
        } else {
            fallbackAvatar
        }
    }

    private var fallbackAvatar: some View {
        ZStack {
            ChatTheme.color(conversation.avatarTint.rawValue)
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
