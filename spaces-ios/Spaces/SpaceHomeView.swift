import SwiftUI

struct SpaceHomeView: View {
    let spaceID: UUID
    @Binding var state: ChatListState
    @Binding var presentation: SpaceHomeState
    let onOpen: (Conversation) -> Void
    let onActivities: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var scaledAvatarSize: CGFloat = 48

    private var space: ProductSpace? { state.conversation(spaceID)?.space }
    private var workCoordinate: String { "space.work.\(spaceID)" }
    private var personalCoordinate: String { "space.personal.\(spaceID)" }
    private var combinedCoordinate: String { "space.combined.\(spaceID)" }

    var body: some View {
        Group {
            if let space {
                GeometryReader { geometry in
                    if geometry.size.height < 500 || dynamicTypeSize.isAccessibilitySize {
                        combinedList(space)
                    } else {
                        VStack(spacing: 0) {
                            identityHeader(space)
                            GeometryReader { areas in
                                VStack(spacing: 0) {
                                    workPanel(space)
                                        .frame(height: areas.size.height * 0.6)
                                    personalPanel
                                        .frame(height: areas.size.height * 0.4)
                                }
                            }
                        }
                    }
                }
            } else {
                ContentUnavailableView("Пространство недоступно", systemImage: "square.dashed")
            }
        }
        .background(.white)
        .accessibilityIdentifier("space.\(spaceID.uuidString)")
        .modifier(EntryHeader(title: space?.title ?? "Пространство",
                              onActivities: onActivities, background: ChatTheme.accentBackground))
    }

    private func identityHeader(_ space: ProductSpace) -> some View {
        HStack(spacing: 12) {
            Text(state.conversation(spaceID)?.initials ?? "СП")
                .font(.system(size: min(scaledAvatarSize, 64) * 0.4, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: min(scaledAvatarSize, 64), height: min(scaledAvatarSize, 64))
                .background(ChatTheme.accent,
                            in: RoundedRectangle(cornerRadius: min(scaledAvatarSize, 64) * 14 / 48,
                                                 style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("Пространство")
                    .font(.headline)
                    .foregroundStyle(ChatTheme.accent)
                Text(space.sectionSummary)
                    .font(.subheadline)
                    .foregroundStyle(ChatTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ChatTheme.accentBackground)
        .overlay(alignment: .bottom) {
            Rectangle().fill(ChatTheme.accent.opacity(0.18)).frame(height: 0.5)
        }
    }

    private func workPanel(_ space: ProductSpace) -> some View {
        VStack(spacing: 0) {
            areaHeading("В пространстве")
            RestoringSpaceList(scrollID: $presentation.workScrollID, coordinate: workCoordinate) {
                workSections(space, coordinate: workCoordinate)
            }
        }
    }

    private var personalPanel: some View {
        VStack(spacing: 0) {
            areaHeading("Личные сообщения", subtitle: "Последние 5 диалогов")
            RestoringSpaceList(scrollID: $presentation.personalScrollID, coordinate: personalCoordinate) {
                personalRows(coordinate: personalCoordinate)
            }
        }
    }

    private func combinedList(_ space: ProductSpace) -> some View {
        RestoringSpaceList(scrollID: $presentation.combinedScrollID, coordinate: combinedCoordinate) {
            identityHeader(space)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .id(spaceID)
                .modifier(VisibleSpaceRow(id: spaceID, coordinate: combinedCoordinate))
            areaHeading("В пространстве")
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
            workSections(space, coordinate: combinedCoordinate)
            Section {
                personalRows(coordinate: combinedCoordinate)
            } header: {
                areaHeading("Личные сообщения", subtitle: "Последние 5 диалогов")
                    .padding(.horizontal, -16)
            }
            .textCase(nil)
        }
    }

    private func areaHeading(_ title: String, subtitle: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.headline).foregroundStyle(ChatTheme.primaryText)
                .accessibilityAddTraits(.isHeader)
            if let subtitle {
                Text(subtitle).font(.caption).foregroundStyle(ChatTheme.secondaryText)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .overlay(alignment: .bottom) {
            Rectangle().fill(ChatTheme.separator).frame(height: 0.5)
        }
    }

    @ViewBuilder
    private func workSections(_ space: ProductSpace, coordinate: String) -> some View {
        if !state.conversations.contains(where: { $0.parentSpaceID == spaceID }) {
            emptyRow("В пространстве пока нет чатов и каналов")
        } else {
            ForEach(state.spaceConversations(spaceID)) { conversation in
                conversationRow(conversation, coordinate: coordinate)
            }
            ForEach(space.sections) { section in
                Section {
                    if presentation.isExpanded(section.id) {
                        let conversations = state.spaceConversations(spaceID, sectionID: section.id)
                        if conversations.isEmpty {
                            emptyRow("Здесь пока нет чатов и каналов")
                        } else {
                            ForEach(conversations) { conversation in
                                conversationRow(conversation, coordinate: coordinate)
                            }
                        }
                    }
                } header: {
                    sectionHeading(section)
                        .id(section.id)
                        .modifier(VisibleSpaceRow(id: section.id, coordinate: coordinate, isSectionHeader: true))
                }
                .textCase(nil)
            }
        }
    }

    private func sectionHeading(_ section: SpaceSection) -> some View {
        let expanded = presentation.isExpanded(section.id)
        let unread = state.sectionUnreadCount(spaceID, sectionID: section.id)
        let mentions = state.sectionMentionCount(spaceID, sectionID: section.id)
        return Button {
            presentation.toggleSection(section.id)
        } label: {
            HStack(spacing: 8) {
                Text(section.title).font(.headline).foregroundStyle(ChatTheme.primaryText)
                Image(systemName: expanded ? "chevron.down" : "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ChatTheme.secondaryText)
                Spacer(minLength: 8)
                if mentions > 0 {
                    Text("@").font(.body.weight(.semibold)).foregroundStyle(ChatTheme.accent)
                }
                if unread > 0 {
                    Text("\(unread)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .frame(minWidth: 20, minHeight: 20)
                        .background(ChatTheme.accent, in: Capsule())
                        .fixedSize()
                }
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Раздел \(section.title)")
        .accessibilityValue("\(expanded ? "Развёрнут" : "Свёрнут"). Непрочитанных: \(unread). Упоминаний вас: \(mentions)")
        .accessibilityHint("Двойное нажатие раскрывает или сворачивает раздел")
    }

    @ViewBuilder
    private func personalRows(coordinate: String) -> some View {
        if state.recentPersonalConversations.isEmpty {
            emptyRow("Личных диалогов пока нет")
        } else {
            ForEach(state.recentPersonalConversations) { conversation in
                conversationRow(conversation, coordinate: coordinate)
            }
        }
    }

    private func conversationRow(_ conversation: Conversation, coordinate: String) -> some View {
        Button {
            onOpen(conversation)
        } label: {
            ConversationRow(conversation: conversation,
                            parentSpaceTitle: conversation.isChild ? space?.title : nil,
                            showMentions: true,
                            isParentMuted: conversation.isChild && state.conversation(spaceID)?.isMuted == true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .id(conversation.id)
        .accessibilityHint(conversation.isPersonal ? "Открыть личный диалог" : "Открыть диалог в пространстве")
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .listRowBackground(Color.white)
        .listRowSeparatorTint(ChatTheme.separator)
        .modifier(ReadMuteActions(conversation: conversation,
                                  onRead: { state.markRead(conversation.id) },
                                  onMute: { state.toggleMuted(conversation.id) }))
        .modifier(VisibleSpaceRow(id: conversation.id, coordinate: coordinate))
    }

    private func emptyRow(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(ChatTheme.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 12)
            .listRowSeparator(.hidden)
    }
}

/// Native List retains swipe actions; the saved visible ID restores each area's scroll.
private struct RestoringSpaceList<Content: View>: View {
    @Binding var scrollID: UUID?
    let coordinate: String
    let content: () -> Content
    @State private var isRestoring = true

    init(scrollID: Binding<UUID?>, coordinate: String, @ViewBuilder content: @escaping () -> Content) {
        _scrollID = scrollID
        self.coordinate = coordinate
        self.content = content
    }

    var body: some View {
        GeometryReader { viewport in
            ScrollViewReader { proxy in
                List { content() }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .coordinateSpace(name: coordinate)
                    .onPreferenceChange(SpaceRowFrames.self) { frames in
                        guard !isRestoring else { return }
                        let visible = frames.filter {
                            $0.value.rect.maxY > 0 && $0.value.rect.minY < viewport.size.height
                        }
                        // A sticky section header must not reset a deep scroll to its first row.
                        let rows = visible.filter { !$0.value.isSectionHeader }
                        let candidates = rows.isEmpty ? visible : rows
                        if let first = candidates.min(by: { $0.value.rect.minY < $1.value.rect.minY })?.key,
                           scrollID != first { scrollID = first }
                    }
                    .task {
                        let saved = scrollID
                        await Task.yield()
                        guard !Task.isCancelled else { return }
                        if let saved { proxy.scrollTo(saved, anchor: .top) }
                        isRestoring = false
                    }
                    .onDisappear { isRestoring = true }
            }
        }
    }
}

private struct SpaceRowFrame: Equatable {
    let rect: CGRect
    let isSectionHeader: Bool
}

private struct SpaceRowFrames: PreferenceKey {
    static let defaultValue: [UUID: SpaceRowFrame] = [:]

    static func reduce(value: inout [UUID: SpaceRowFrame], nextValue: () -> [UUID: SpaceRowFrame]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct VisibleSpaceRow: ViewModifier {
    let id: UUID
    let coordinate: String
    var isSectionHeader = false

    func body(content: Content) -> some View {
        content.background {
            GeometryReader { geometry in
                Color.clear.preference(key: SpaceRowFrames.self,
                                       value: [id: SpaceRowFrame(rect: geometry.frame(in: .named(coordinate)),
                                                                isSectionHeader: isSectionHeader)])
            }
        }
    }
}

#Preview("Пространство — iPhone") {
    NavigationStack {
        SpaceHomeView(spaceID: ProductSpace.sber.id, state: .constant(ChatListState()),
                      presentation: .constant(SpaceHomeState()), onOpen: { _ in }, onActivities: {})
    }
    .frame(width: 393, height: 852)
    .tint(ChatTheme.accent)
    .preferredColorScheme(.light)
}

#Preview("Пространство — iPad") {
    NavigationStack {
        SpaceHomeView(spaceID: ProductSpace.sber.id, state: .constant(ChatListState()),
                      presentation: .constant(SpaceHomeState()), onOpen: { _ in }, onActivities: {})
    }
    .frame(width: 1024, height: 768)
    .tint(ChatTheme.accent)
    .preferredColorScheme(.light)
}

#Preview("Пространство — крупный шрифт") {
    NavigationStack {
        SpaceHomeView(spaceID: ProductSpace.sber.id, state: .constant(ChatListState()),
                      presentation: .constant(SpaceHomeState()), onOpen: { _ in }, onActivities: {})
    }
    .environment(\.dynamicTypeSize, .accessibility3)
    .frame(width: 393, height: 852)
    .tint(ChatTheme.accent)
    .preferredColorScheme(.light)
}
