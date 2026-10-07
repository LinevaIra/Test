import SwiftUI

struct TeamResourcesView: View {
    let conversationID: UUID
    @Binding var state: ChatListState
    @Binding var presentation: DialoguePresentation
    var selectedSessionID: UUID? = nil

    private var resources: [TeamResource] {
        state.activity.resources.filter { $0.conversationID == conversationID && $0.tab == presentation.tab && $0.isAccessible }
    }
    private var scrollID: Binding<UUID?> {
        Binding(get: { presentation.resourceScrollIDs[presentation.tab] },
                set: { presentation.resourceScrollIDs[presentation.tab] = $0 })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if resources.isEmpty {
                    Text(emptyText).foregroundStyle(ChatTheme.secondaryText).padding(.vertical, 24)
                } else if let resource = resources.first {
                    switch presentation.tab {
                    case .voice: voiceRoom(resource)
                    case .board: board(resource)
                    case .notes: notes
                    case .messages: EmptyView()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16).scrollTargetLayout()
        }
        .scrollPosition(id: scrollID)
        .background(.white)
    }

    private var emptyText: String {
        switch presentation.tab {
        case .voice: return "Голосовая комната пока не создана"
        case .board: return "Доска пока не создана"
        case .notes: return "Заметок пока нет"
        case .messages: return "Сообщений пока нет"
        }
    }

    private func voiceRoom(_ resource: TeamResource) -> some View {
        let session = selectedSessionID.flatMap { state.activity.session($0) }.flatMap { $0.resourceID == resource.id ? $0 : nil }
            ?? state.activity.sessions.first { $0.resourceID == resource.id && $0.isActive }
        return VStack(alignment: .leading, spacing: 16) {
            Label(resource.title, systemImage: "video").font(.title3.weight(.semibold))
            Text(session == nil ? "Сейчас нет встречи" : session?.isActive == true ? "Идёт встреча" : "Завершённая встреча · Пропущена")
                .foregroundStyle(session?.isActive == true ? ChatTheme.accent : ChatTheme.secondaryText)
            if let session {
                ForEach(session.participants, id: \.self) { name in
                    HStack {
                        InitialAvatar(initials: String(name.prefix(1)).uppercased())
                        Text(name)
                    }
                }
            } else { Text("Сейчас нет участников").foregroundStyle(ChatTheme.secondaryText) }
            if let session {
                Text(session.lastActivityAt, style: .date).font(.caption).foregroundStyle(ChatTheme.secondaryText)
            }
        }
        .id(resource.id)
    }

    private func board(_ resource: TeamResource) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(resource.title, systemImage: "rectangle.split.3x1").font(.title3.weight(.semibold))
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    boardColumn("К работе", task: "Обновить документацию")
                    boardColumn("В работе", task: "Проверить сборку")
                    boardColumn("Готово", task: "Исправить навигацию")
                }
            }
        }
        .id(resource.id)
    }

    private func boardColumn(_ title: String, task: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
            Text(task).padding(12).frame(maxWidth: .infinity, alignment: .leading)
                .background(.white, in: RoundedRectangle(cornerRadius: 12))
        }
        .padding(12).frame(width: 220, alignment: .leading)
        .background(ChatTheme.accentBackground, in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder private var notes: some View {
        if let id = presentation.selectedNoteID {
            if let note = resources.first(where: { $0.id == id }) {
                Button { presentation.selectedNoteID = nil } label: {
                    Label("Все заметки", systemImage: "chevron.left")
                }.frame(minHeight: 44)
                Text(note.title).font(.title3.weight(.semibold))
                Text(note.text).fixedSize(horizontal: false, vertical: true).id(note.id)
            } else { Text("Ресурс недоступен").foregroundStyle(ChatTheme.secondaryText) }
        } else {
            ForEach(resources) { note in
                Button { presentation.selectedNoteID = note.id } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "note.text").foregroundStyle(ChatTheme.accent)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(note.title).font(.headline)
                            Text("Команда разработки · \(note.updatedBy)").font(.caption).foregroundStyle(ChatTheme.secondaryText)
                            if let updatedAt = note.updatedAt {
                                Text(updatedAt, style: .date).font(.caption).foregroundStyle(ChatTheme.secondaryText)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(ChatTheme.secondaryText)
                    }
                    .padding(.vertical, 8).contentShape(Rectangle())
                }
                .buttonStyle(.plain).id(note.id)
                Divider()
            }
        }
    }
}
