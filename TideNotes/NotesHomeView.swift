import SwiftUI
import SwiftData

struct NotesHomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Note.updatedAt, order: .reverse) private var allNotes: [Note]
    @State private var search = ""
    @State private var selectedNote: Note?

    private var notes: [Note] {
        allNotes
            .filter { !$0.isDeleted }
            .filter {
                search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) || $0.body.localizedCaseInsensitiveContains(search)
            }
            .sorted {
                if $0.isPinned != $1.isPinned { return $0.isPinned }
                return $0.updatedAt > $1.updatedAt
            }
    }

    var body: some View {
        NavigationStack {
            Group {
                if notes.isEmpty {
                    ContentUnavailableView(
                        search.isEmpty ? "No Notes" : "No Results",
                        systemImage: search.isEmpty ? "note.text" : "magnifyingglass",
                        description: Text(search.isEmpty ? "Tap the compose button to make your first TideNote." : "Try another search.")
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
                                Button {
                                    note.isPinned.toggle()
                                    note.updatedAt = .now
                                } label: {
                                    Label(note.isPinned ? "Unpin" : "Pin", systemImage: note.isPinned ? "pin.slash" : "pin")
                                }
                                .tint(.orange)
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    note.isDeleted = true
                                    note.updatedAt = .now
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("TideNotes")
            .searchable(text: $search, prompt: "Search notes")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        MoreView()
                    } label: {
                        Image(systemName: "folder")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: newNote) {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("New note")
                }
            }
            .navigationDestination(item: $selectedNote) { note in
                NoteEditorView(note: note)
            }
        }
    }

    private func newNote() {
        let note = Note()
        context.insert(note)
        selectedNote = note
    }
}

private struct NoteRow: View {
    let note: Note

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                if note.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                Text(note.displayTitle)
                    .font(.headline)
                    .lineLimit(1)
            }
            HStack(spacing: 8) {
                Text(note.updatedAt, style: .date)
                    .foregroundStyle(.secondary)
                Text(note.preview)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .font(.subheadline)
        }
        .padding(.vertical, 4)
    }
}
