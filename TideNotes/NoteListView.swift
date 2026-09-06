import SwiftUI
import SwiftData

enum NoteListMode {
    case all
    case pinned
    case recentlyDeleted
    case folder(NoteFolder)

    var title: String {
        switch self {
        case .all: return "All Notes"
        case .pinned: return "Pinned"
        case .recentlyDeleted: return "Recently Deleted"
        case .folder(let folder): return folder.name
        }
    }
}

struct NoteListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Note.updatedAt, order: .reverse) private var allNotes: [Note]

    let mode: NoteListMode

    @State private var search = ""
    @State private var createdNote: Note?
    @State private var openingCreatedNote = false

    private var notes: [Note] {
        let scoped = allNotes.filter { note in
            switch mode {
            case .all:
                return !note.isDeleted
            case .pinned:
                return !note.isDeleted && note.isPinned
            case .recentlyDeleted:
                return note.isDeleted
            case .folder(let folder):
                return !note.isDeleted && note.folder?.id == folder.id
            }
        }

        let searched = scoped.filter { note in
            guard !search.isEmpty else { return true }
            return note.title.localizedCaseInsensitiveContains(search)
                || note.body.localizedCaseInsensitiveContains(search)
                || note.tagsText.localizedCaseInsensitiveContains(search)
        }

        return searched.sorted {
            if $0.isPinned != $1.isPinned && !isRecentlyDeleted {
                return $0.isPinned
            }
            return $0.updatedAt > $1.updatedAt
        }
    }

    private var isRecentlyDeleted: Bool {
        if case .recentlyDeleted = mode { return true }
        return false
    }

    var body: some View {
        Group {
            if notes.isEmpty {
                ContentUnavailableView(
                    search.isEmpty ? emptyTitle : "No Results",
                    systemImage: search.isEmpty ? emptyIcon : "magnifyingglass",
                    description: Text(search.isEmpty ? emptyMessage : "Try a different search.")
                )
            } else {
                List {
                    ForEach(notes) { note in
                        NavigationLink {
                            NoteEditorView(note: note)
                        } label: {
                            NoteRow(note: note)
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            if isRecentlyDeleted {
                                Button {
                                    recover(note)
                                } label: {
                                    Label("Recover", systemImage: "arrow.uturn.backward")
                                }
                                .tint(.green)
                            } else {
                                Button {
                                    note.isPinned.toggle()
                                    save(note)
                                } label: {
                                    Label(note.isPinned ? "Unpin" : "Pin", systemImage: note.isPinned ? "pin.slash" : "pin")
                                }
                                .tint(.orange)
                            }
                        }
                        .swipeActions {
                            if isRecentlyDeleted {
                                Button(role: .destructive) {
                                    context.delete(note)
                                    try? context.save()
                                } label: {
                                    Label("Delete Forever", systemImage: "trash.slash")
                                }
                            } else {
                                Button(role: .destructive) {
                                    note.deletedAt = .now
                                    save(note)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(mode.title)
        .searchable(text: $search, prompt: "Search notes")
        .toolbar {
            if !isRecentlyDeleted {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        let note = Note(folder: folderForNewNote)
                        context.insert(note)
                        createdNote = note
                        openingCreatedNote = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("New note")
                }
            }
        }
        .navigationDestination(isPresented: $openingCreatedNote) {
            if let createdNote {
                NoteEditorView(note: createdNote)
            }
        }
    }

    private var folderForNewNote: NoteFolder? {
        if case .folder(let folder) = mode { return folder }
        return nil
    }

    private var emptyTitle: String {
        switch mode {
        case .recentlyDeleted: return "Nothing Deleted"
        case .pinned: return "No Pinned Notes"
        default: return "No Notes"
        }
    }

    private var emptyIcon: String {
        switch mode {
        case .recentlyDeleted: return "trash"
        case .pinned: return "pin"
        default: return "note.text"
        }
    }

    private var emptyMessage: String {
        switch mode {
        case .recentlyDeleted: return "Deleted notes will appear here."
        case .pinned: return "Pin important notes so they stay easy to find."
        default: return "Tap the compose button to create a note."
        }
    }

    private func recover(_ note: Note) {
        note.deletedAt = nil
        save(note)
    }

    private func save(_ note: Note) {
        note.touch()
        try? context.save()
    }
}

struct NoteRow: View {
    let note: Note

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                if note.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                if note.isLocked {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(note.displayTitle)
                    .font(.headline)
                    .lineLimit(1)
            }

            HStack(spacing: 8) {
                Text(note.updatedAt, style: .date)
                Text(note.isLocked ? "Locked Note" : note.preview)
                    .lineLimit(1)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if !note.tags.isEmpty && !note.isLocked {
                Text(note.tags.map { "#\($0)" }.joined(separator: "  "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}
