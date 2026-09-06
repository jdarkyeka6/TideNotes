import SwiftUI
import SwiftData

struct NotesHomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \NoteFolder.createdAt) private var folders: [NoteFolder]
    @Query(sort: \Note.updatedAt, order: .reverse) private var notes: [Note]

    @State private var showingNewFolder = false
    @State private var folderName = ""
    @State private var folderToRename: NoteFolder?
    @State private var renameText = ""
    @State private var showingRenameFolder = false
    @State private var createdNote: Note?
    @State private var openingCreatedNote = false

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
                        Text("No folders yet")
                            .foregroundStyle(.secondary)
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
                            .contextMenu {
                                Button {
                                    folderToRename = folder
                                    renameText = folder.name
                                    showingRenameFolder = true
                                } label: {
                                    Label("Rename", systemImage: "pencil")
                                }

                                Button(role: .destructive) {
                                    delete(folder)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    delete(folder)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }

                                Button {
                                    folderToRename = folder
                                    renameText = folder.name
                                    showingRenameFolder = true
                                } label: {
                                    Label("Rename", systemImage: "pencil")
                                }
                                .tint(.blue)
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

                    Button {
                        createAndOpenNote()
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("New note")
                }
            }
            .navigationDestination(isPresented: $openingCreatedNote) {
                if let createdNote {
                    NoteEditorView(note: createdNote)
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
            .alert("Rename Folder", isPresented: $showingRenameFolder) {
                TextField("Folder name", text: $renameText)
                Button("Cancel", role: .cancel) {
                    folderToRename = nil
                    renameText = ""
                }
                Button("Save") {
                    renameFolder()
                }
            }
        }
    }

    private func createAndOpenNote() {
        let note = Note()
        context.insert(note)
        try? context.save()
        createdNote = note
        openingCreatedNote = true
    }

    private func createFolder() {
        let name = folderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        context.insert(NoteFolder(name: name))
        try? context.save()
        folderName = ""
    }

    private func renameFolder() {
        let name = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let folderToRename else { return }
        folderToRename.name = name
        try? context.save()
        self.folderToRename = nil
        renameText = ""
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
