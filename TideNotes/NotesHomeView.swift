import SwiftUI
import SwiftData

struct NotesHomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \NoteFolder.createdAt) private var folders: [NoteFolder]
    @Query(sort: \Note.updatedAt, order: .reverse) private var notes: [Note]

    @State private var showingNewFolder = false
    @State private var folderName = ""

    private var activeNotes: [Note] { notes.filter { !$0.isDeleted } }
    private var pinnedCount: Int { activeNotes.filter(\.isPinned).count }
    private var deletedCount: Int { notes.filter(\.isDeleted).count }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        NoteListView(mode: .all)
                    } label: {
                        FolderRow(icon: "note.text", title: "All Notes", count: activeNotes.count)
                    }

                    NavigationLink {
                        NoteListView(mode: .pinned)
                    } label: {
                        FolderRow(icon: "pin.fill", title: "Pinned", count: pinnedCount)
                    }

                    NavigationLink {
                        NoteListView(mode: .recentlyDeleted)
                    } label: {
                        FolderRow(icon: "trash", title: "Recently Deleted", count: deletedCount)
                    }
                }

                Section("Folders") {
                    if folders.isEmpty {
                        ContentUnavailableView(
                            "No Folders",
                            systemImage: "folder",
                            description: Text("Create a folder to organise your notes.")
                        )
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(folders) { folder in
                            NavigationLink {
                                NoteListView(mode: .folder(folder))
                            } label: {
                                FolderRow(
                                    icon: "folder.fill",
                                    title: folder.name,
                                    count: activeNotes.filter { $0.folder?.id == folder.id }.count
                                )
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    delete(folder)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("TideNotes")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showingNewFolder = true
                    } label: {
                        Image(systemName: "folder.badge.plus")
                    }
                    .accessibilityLabel("New folder")

                    NavigationLink {
                        NoteEditorView(note: makeNote())
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("New note")
                }
            }
            .alert("New Folder", isPresented: $showingNewFolder) {
                TextField("Folder name", text: $folderName)
                Button("Cancel", role: .cancel) {
                    folderName = ""
                }
                Button("Create") {
                    createFolder()
                }
            } message: {
                Text("Give this folder a name.")
            }
        }
    }

    private func makeNote() -> Note {
        let note = Note()
        context.insert(note)
        return note
    }

    private func createFolder() {
        let name = folderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        context.insert(NoteFolder(name: name))
        try? context.save()
        folderName = ""
    }

    private func delete(_ folder: NoteFolder) {
        for note in notes where note.folder?.id == folder.id {
            note.folder = nil
            note.touch()
        }
        context.delete(folder)
        try? context.save()
    }
}

private struct FolderRow: View {
    let icon: String
    let title: String
    let count: Int

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.tint)
                .frame(width: 24)
            Text(title)
            Spacer()
            Text("\(count)")
                .foregroundStyle(.secondary)
        }
    }
}
