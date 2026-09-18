import SwiftUI
import SwiftData

enum NoteListMode {
    case all
    case pinned
    case today
    case attachments
    case recentlyDeleted
    case folder(NoteFolder)

    var title: String {
        switch self {
        case .all: return "All Notes"
        case .pinned: return "Pinned"
        case .today: return "Today"
        case .attachments: return "Attachments"
        case .recentlyDeleted: return "Recently Deleted"
        case .folder(let folder): return folder.name
        }
    }

    var icon: String {
        switch self {
        case .all: return "note.text"
        case .pinned: return "pin.fill"
        case .today: return "clock.fill"
        case .attachments: return "paperclip"
        case .recentlyDeleted: return "trash"
        case .folder: return "folder.fill"
        }
    }
}

private enum NoteSort: String, CaseIterable, Identifiable {
    case updated = "Last Edited"
    case created = "Date Created"
    case title = "Title"

    var id: String { rawValue }
}

struct NoteListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Note.updatedAt, order: .reverse) private var allNotes: [Note]

    let mode: NoteListMode

    @State private var search = ""
    @State private var sort: NoteSort = .updated
    @State private var createdNote: Note?
    @State private var openingCreatedNote = false

    private var notes: [Note] {
        let scoped = allNotes.filter { note in
            switch mode {
            case .all:
                return !note.isDeleted
            case .pinned:
                return !note.isDeleted && note.isPinned
            case .today:
                return !note.isDeleted && Calendar.current.isDateInToday(note.updatedAt)
            case .attachments:
                return !note.isDeleted && (note.photoData != nil || note.drawingData != nil)
            case .recentlyDeleted:
                return note.isDeleted
            case .folder(let folder):
                return !note.isDeleted && note.folder?.id == folder.id
            }
        }

        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        let searched = scoped.filter { note in
            guard !query.isEmpty else { return true }
            return note.title.localizedCaseInsensitiveContains(query)
                || note.body.localizedCaseInsensitiveContains(query)
                || note.tagsText.localizedCaseInsensitiveContains(query)
        }

        return searched.sorted { lhs, rhs in
            if !isRecentlyDeleted && lhs.isPinned != rhs.isPinned {
                return lhs.isPinned
            }

            switch sort {
            case .updated:
                return lhs.updatedAt > rhs.updatedAt
            case .created:
                return lhs.createdAt > rhs.createdAt
            case .title:
                return lhs.displayTitle.localizedCaseInsensitiveCompare(rhs.displayTitle) == .orderedAscending
            }
        }
    }

    private var isRecentlyDeleted: Bool {
        if case .recentlyDeleted = mode { return true }
        return false
    }

    var body: some View {
        Group {
            if notes.isEmpty {
                emptyState
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
                                    Label(
                                        note.isPinned ? "Unpin" : "Pin",
                                        systemImage: note.isPinned ? "pin.slash" : "pin"
                                    )
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
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $search, prompt: "Search \(mode.title.lowercased())")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    Picker("Sort", selection: $sort) {
                        ForEach(NoteSort.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
                .accessibilityLabel("Sort notes")

                if !isRecentlyDeleted {
                    Button {
                        let note = Note(folder: folderForNewNote)
                        context.insert(note)
                        try? context.save()
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

    private var emptyState: some View {
        ContentUnavailableView {
            Label(search.isEmpty ? emptyTitle : "No Results", systemImage: search.isEmpty ? mode.icon : "magnifyingglass")
        } description: {
            Text(search.isEmpty ? emptyMessage : "Try a different search.")
        } actions: {
            if search.isEmpty && !isRecentlyDeleted {
                Button("New Note") {
                    let note = Note(folder: folderForNewNote)
                    context.insert(note)
                    try? context.save()
                    createdNote = note
                    openingCreatedNote = true
                }
                .buttonStyle(.borderedProminent)
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
        case .today: return "Nothing Yet Today"
        case .attachments: return "No Attachments"
        default: return "No Notes"
        }
    }

    private var emptyMessage: String {
        switch mode {
        case .recentlyDeleted:
            return "Deleted notes will appear here."
        case .pinned:
            return "Pin important notes so they stay easy to find."
        case .today:
            return "Notes you edit today will appear here."
        case .attachments:
            return "Notes with photos or drawings will appear here."
        default:
            return "Create a note and start writing."
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
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 7) {
                Text(note.displayTitle)
                    .font(.headline)
                    .lineLimit(1)

                if note.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }

                if note.isLocked {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            Text(note.isLocked ? "Locked Note" : note.preview)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack(spacing: 8) {
                Text(note.updatedAt, style: .relative)

                if note.photoData != nil || note.drawingData != nil {
                    Label("Attachment", systemImage: "paperclip")
                }

                if !note.tags.isEmpty && !note.isLocked {
                    Text(note.tags.prefix(2).map { "#\($0)" }.joined(separator: " "))
                        .lineLimit(1)
                }
            }
            .font(.caption)
            .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
    }
}
