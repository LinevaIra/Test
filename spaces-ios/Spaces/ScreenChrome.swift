import SwiftUI

/// One layout owns all three columns; the profile cannot overlap navigation actions.
struct AppScreenHeader: ViewModifier {
    let title: String
    var subtitle: String? = nil
    var initials: String? = nil
    var background: Color = .white
    var onActivities: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize

    func body(content: Content) -> some View {
        content
            .navigationBarBackButtonHidden()
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                HStack(spacing: 8) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left").font(.title3.weight(.medium))
                            .frame(width: 44, height: 44).contentShape(Rectangle())
                    }
                    .accessibilityLabel("Назад")
                    HStack(spacing: 8) {
                        if let initials { InitialAvatar(initials: initials, size: 36, square: true) }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(title).font(.headline).foregroundStyle(ChatTheme.primaryText)
                                .lineLimit(typeSize.isAccessibilitySize ? nil : 1)
                                .accessibilityAddTraits(.isHeader)
                            if let subtitle {
                                Text(subtitle).font(.caption).foregroundStyle(ChatTheme.secondaryText)
                                    .lineLimit(typeSize.isAccessibilitySize ? nil : 2)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity)
                    .layoutPriority(1)
                    if let onActivities { ActivitiesButton(action: onActivities) }
                    else { Color.clear.frame(width: 44, height: 44).accessibilityHidden(true) }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8).padding(.vertical, 6)
                .background(background)
                .overlay(alignment: .bottom) { ChatTheme.separator.frame(height: 0.5) }
            }
    }
}

struct InitialAvatar: View {
    let initials: String
    var size: CGFloat = 32
    var square = false
    var tint: Color = ChatTheme.accent
    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.4, weight: .semibold)).foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(tint, in: RoundedRectangle(cornerRadius: square ? size * 0.3 : size / 2, style: .continuous))
            .accessibilityHidden(true)
    }
}

struct UnreadBadge: View {
    let count: Int
    var muted = false
    var body: some View {
        if count > 0 {
            Text("\(count)").font(.caption.weight(.semibold)).foregroundStyle(.white)
                .padding(.horizontal, 6).padding(.vertical, 3).frame(minWidth: 20)
                .background(muted ? ChatTheme.mutedBadge : ChatTheme.accent, in: Capsule())
                .fixedSize()
        }
    }
}
