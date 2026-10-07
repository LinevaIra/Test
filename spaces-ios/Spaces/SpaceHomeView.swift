import SwiftUI
import UniformTypeIdentifiers

struct SpaceHomeView: View {
    let spaceID: UUID
    @Binding var state: ChatListState
    @Binding var presentation: SpaceHomeState
    let onOpen: (Conversation) -> Void
    let onActivities: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var activeDragToken: String?

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
                            workPanel(space)
                                .frame(maxHeight: .infinity)
                            personalPanel
                                .frame(height: presentation.personalExpanded ? geometry.size.height * 0.4 : 54)
                        }
                    }
                }
            } else {
                ContentUnavailableView("Пространство недоступно", systemImage: "square.dashed")
            }
        }
        .background(.white)
        .accessibilityIdentifier("space.\(spaceID.uuidString)")
        .modifier(AppScreenHeader(title: space?.title ?? "Пространство", subtitle: "Пространство",
                                  initials: state.conversation(spaceID)?.initials ?? "СП",
                                  background: ChatTheme.accentBackground, onActivities: onActivities))
    }

    private func workPanel(_ space: ProductSpace) -> some View {
        VStack(spacing: 0) {
            areaHeading("В пространстве")
            RestoringSpaceList(scrollID: $presentation.workScrollID, coordinate: workCoordinate, orderedIDs: workIDs) {
                workSections(space, coordinate: workCoordinate)
            }
        }
    }

    private var personalPanel: some View {
        VStack(spacing: 0) {
            personalHeading
            if presentation.personalExpanded {
                RestoringSpaceList(scrollID: $presentation.personalScrollID, coordinate: personalCoordinate) {
                    personalRows(coordinate: personalCoordinate)
                }
            }
        }
    }

    private func combinedList(_ space: ProductSpace) -> some View {
        RestoringSpaceList(scrollID: $presentation.combinedScrollID, coordinate: combinedCoordinate, orderedIDs: workIDs) {
            areaHeading("В пространстве")
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
            workSections(space, coordinate: combinedCoordinate)
            Section {
                if presentation.personalExpanded { personalRows(coordinate: combinedCoordinate) }
            } header: {
                personalHeading
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
        }
        ForEach(state.spaceConversations(spaceID)) { conversation in
                conversationRow(conversation, coordinate: coordinate)
            }
            ForEach(state.orderedSections(spaceID)) { section in
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

    private var workIDs: [UUID] {
        state.spaceConversations(spaceID).map(\.id) + state.orderedSections(spaceID).flatMap { section in
            [section.id] + (presentation.isExpanded(section.id) ? state.spaceConversations(spaceID, sectionID: section.id).map(\.id) : [])
        }
    }

    private var personalHeading: some View {
        Button { presentation.personalExpanded.toggle() } label: {
            HStack(spacing: 8) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        Text("Личные сообщения").font(.headline)
                        Text("вне пространства").font(.caption).foregroundStyle(ChatTheme.secondaryText)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Личные сообщения").font(.headline)
                        Text("вне пространства").font(.caption).foregroundStyle(ChatTheme.secondaryText)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: presentation.personalExpanded ? "chevron.down" : "chevron.right")
                    .foregroundStyle(ChatTheme.secondaryText)
            }
            .foregroundStyle(ChatTheme.primaryText)
            .padding(.horizontal, 16).padding(.vertical, 8).frame(minHeight: 44)
            .background(.white)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Личные сообщения, вне пространства")
        .accessibilityValue(presentation.personalExpanded ? "Развёрнут" : "Свёрнут")
    }

    private func sectionHeading(_ section: SpaceSection) -> some View {
        let expanded = presentation.isExpanded(section.id)
        let ids = state.orderedSections(spaceID).map(\.id)
        return HStack(spacing: 4) {
            Button { presentation.toggleSection(section.id) } label: {
                HStack(spacing: 8) {
                    Text(section.title).font(.headline).foregroundStyle(ChatTheme.primaryText)
                    Image(systemName: expanded ? "chevron.down" : "chevron.right")
                        .font(.caption).foregroundStyle(ChatTheme.secondaryText)
                    Spacer(minLength: 8)
                    if state.sectionMentionCount(spaceID, sectionID: section.id) > 0 {
                        Text("@").foregroundStyle(ChatTheme.accent)
                    }
                    UnreadBadge(count: state.sectionUnreadCount(spaceID, sectionID: section.id))
                }
                .frame(minHeight: 44).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Раздел \(section.title)")
            .accessibilityValue("\(expanded ? "Развёрнут" : "Свёрнут"). Непрочитанных: \(state.sectionUnreadCount(spaceID, sectionID: section.id)). Упоминаний: \(state.sectionMentionCount(spaceID, sectionID: section.id))")
            reorderHandle(id: section.id, ids: ids, section: true, title: section.title)
        }
        .modifier(SpaceDropTarget(accepts: activeDragToken?.hasPrefix("section|\(spaceID)|") == true) { token, after in
            activeDragToken = nil
            guard token.hasPrefix("section|\(spaceID)|"),
                  let id = UUID(uuidString: String(token.split(separator: "|").last ?? "")) else { return false }
            return state.moveSection(id, relativeTo: section.id, after: after, spaceID: spaceID)
        })
    }

    private func reorderHandle(id: UUID, ids: [UUID], section: Bool, title: String) -> some View {
        let index = ids.firstIndex(of: id) ?? 0
        let token = "\(section ? "section" : "row")|\(spaceID)|\(id)"
        return Menu {
            Button("Переместить выше") { shift(id, ids: ids, down: false, section: section) }
                .disabled(index == 0)
            Button("Переместить ниже") { shift(id, ids: ids, down: true, section: section) }
                .disabled(index >= ids.count - 1)
        } label: {
            Image(systemName: "line.3.horizontal").foregroundStyle(ChatTheme.secondaryText)
                .frame(width: 44, height: 44).contentShape(Rectangle())
        }
        .onDrag {
            activeDragToken = token
            return NSItemProvider(object: token as NSString)
        } preview: {
            Label(title, systemImage: "line.3.horizontal")
                .padding(10).background(.white, in: RoundedRectangle(cornerRadius: 12))
        }
        .accessibilityLabel("Порядок: \(title)")
        .accessibilityValue("Позиция \(index + 1) из \(ids.count)")
        .accessibilityHint("Удерживайте для перетаскивания или откройте меню перестановки")
        .accessibilityActions {
            if index > 0 { Button("Переместить выше") { shift(id, ids: ids, down: false, section: section) } }
            if index < ids.count - 1 { Button("Переместить ниже") { shift(id, ids: ids, down: true, section: section) } }
        }
    }

    private func shift(_ id: UUID, ids: [UUID], down: Bool, section: Bool) {
        guard let index = ids.firstIndex(of: id) else { return }
        let next = index + (down ? 1 : -1)
        guard ids.indices.contains(next) else { return }
        if section { state.moveSection(id, relativeTo: ids[next], after: down, spaceID: spaceID) }
        else { state.moveRow(id, relativeTo: ids[next], after: down) }
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
        HStack(spacing: 0) {
            Button { onOpen(conversation) } label: {
                ConversationRow(conversation: conversation,
                                parentSpaceTitle: conversation.isChild ? space?.title : nil,
                                showMentions: true,
                                isParentMuted: conversation.isChild && state.conversation(spaceID)?.isMuted == true)
                    .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if let sectionID = conversation.sectionID {
                reorderHandle(id: conversation.id,
                              ids: state.spaceConversations(spaceID, sectionID: sectionID).map(\.id),
                              section: false, title: conversation.title)
            }
        }
        .id(conversation.id)
        .accessibilityHint(conversation.isPersonal ? "Открыть личный диалог" : "Открыть диалог в пространстве")
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .listRowBackground(Color.white)
        .listRowSeparatorTint(ChatTheme.separator)
        .modifier(ReadMuteActions(conversation: conversation,
                                  onRead: { state.markRead(conversation.id) },
                                  onMute: { state.toggleMuted(conversation.id) }))
        .modifier(VisibleSpaceRow(id: conversation.id, coordinate: coordinate))
        .modifier(SpaceDropTarget(accepts: acceptsRowDrag(conversation)) { token, after in
            activeDragToken = nil
            guard conversation.sectionID != nil, token.hasPrefix("row|\(spaceID)|"),
                  let id = UUID(uuidString: String(token.split(separator: "|").last ?? "")) else { return false }
            return state.moveRow(id, relativeTo: conversation.id, after: after)
        })
    }

    private func acceptsRowDrag(_ destination: Conversation) -> Bool {
        guard let token = activeDragToken, token.hasPrefix("row|\(spaceID)|"),
              let id = UUID(uuidString: String(token.split(separator: "|").last ?? "")),
              let source = state.conversation(id), let sectionID = destination.sectionID else { return false }
        return source.parentSpaceID == destination.parentSpaceID && source.sectionID == sectionID
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
struct RestoringSpaceList<Content: View>: View {
    @Binding var scrollID: UUID?
    let coordinate: String
    let content: () -> Content
    let orderedIDs: [UUID]
    @State private var edgeDirection = 0
    @State private var lastVisibleWorkID: UUID?
    @State private var isRestoring = true

    init(scrollID: Binding<UUID?>, coordinate: String, orderedIDs: [UUID] = [], @ViewBuilder content: @escaping () -> Content) {
        _scrollID = scrollID
        self.coordinate = coordinate
        self.content = content
        self.orderedIDs = orderedIDs
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
                        let workFrames = visible.filter { orderedIDs.contains($0.key) }
                        lastVisibleWorkID = workFrames.max(by: { $0.value.rect.maxY < $1.value.rect.maxY })?.key
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
                    .overlay(alignment: .top) { edgeZone(-1) }
                    .overlay(alignment: .bottom) { edgeZone(1) }
                    .task(id: edgeDirection) {
                        let direction = edgeDirection
                        guard direction != 0 else { return }
                        let startingID = direction > 0 ? lastVisibleWorkID : scrollID
                        guard let startingID, var index = orderedIDs.firstIndex(of: startingID) else { return }
                        while !Task.isCancelled && edgeDirection == direction {
                            index += direction
                            guard orderedIDs.indices.contains(index) else { break }
                            withAnimation { proxy.scrollTo(orderedIDs[index], anchor: direction < 0 ? .top : .bottom) }
                            try? await Task.sleep(for: .milliseconds(350))
                        }
                    }
                    .onDisappear { isRestoring = true; edgeDirection = 0 }
            }
        }
    }
    @ViewBuilder private func edgeZone(_ direction: Int) -> some View {
        if !orderedIDs.isEmpty {
            Color.clear.frame(height: 16)
                .onDrop(of: [UTType.text], isTargeted: Binding(
                    get: { edgeDirection == direction },
                    set: { edgeDirection = $0 ? direction : 0 })) { _ in false }
                .accessibilityHidden(true)
        }
    }

}

private struct SpaceDropTarget: ViewModifier {
    let accepts: Bool
    let commit: (String, Bool) -> Bool
    @State private var targeted = false
    @State private var after = false
    @State private var height: CGFloat = 44
    func body(content: Content) -> some View {
        content
            .background { GeometryReader { geometry in Color.clear.onAppear { height = geometry.size.height }
                .onChange(of: geometry.size.height) { _, value in height = value } } }
            .overlay(alignment: after ? .bottom : .top) {
                if targeted && accepts { ChatTheme.accent.frame(height: 2).allowsHitTesting(false) }
            }
            .onDrop(of: [UTType.text], delegate: SpaceReorderDropDelegate(accepts: accepts,
                    height: height, targeted: $targeted, after: $after, commit: commit))
    }
}

private struct SpaceReorderDropDelegate: DropDelegate {
    let accepts: Bool
    let height: CGFloat
    @Binding var targeted: Bool
    @Binding var after: Bool
    let commit: (String, Bool) -> Bool

    func validateDrop(info: DropInfo) -> Bool { accepts && info.hasItemsConforming(to: [UTType.text]) }
    func dropEntered(info: DropInfo) { targeted = true; after = info.location.y > height / 2 }
    func dropExited(info: DropInfo) { targeted = false }
    func dropUpdated(info: DropInfo) -> DropProposal? {
        after = info.location.y > height / 2
        return DropProposal(operation: accepts ? .move : .forbidden)
    }
    func performDrop(info: DropInfo) -> Bool {
        targeted = false
        guard accepts, let provider = info.itemProviders(for: [UTType.text]).first else { return false }
        let insertAfter = info.location.y > height / 2
        _ = provider.loadObject(ofClass: NSString.self) { value, _ in
            guard let value = value as? String else { return }
            DispatchQueue.main.async { _ = commit(value, insertAfter) }
        }
        return true
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

struct VisibleSpaceRow: ViewModifier {
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
