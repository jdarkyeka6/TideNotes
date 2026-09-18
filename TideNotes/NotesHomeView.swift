import SwiftUI
import SwiftData

struct NotesHomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \NoteFolder.createdAt) private var folders: [NoteFolder]
    @Query(sort: \Note.updatedAt, order: .reverse) private var notes: [Note]

    @State private var search = ""
    @State private var showingNewFolder = false
    @State private var folderName = ""
    @State private var folderToRename: NoteFolder?
    @State private var renameText = ""
    @State private var showingRenameFolder = false
    @State private var createdNote: Note?
    @State private var openingCreatedNote = false

    private var activeNotes: [Note] {
        notes.filter { !$0.isDeleted }
    }

    private var pinnedCount: Int {
        activeNotes.filter(\.isPinned).count
    }

    private var todayCount: Int {
        activeNotes.filter { Calendar.current.isDateInToday($0.updatedAt) }.count
    }

    private var attachmentsCount: Int {
        activeNotes.filter { $0.photoData != nil || $0.drawingData != nil }.count
    }

    private var deletedCount: Int {
        notes.filter(\.isDeleted).count
    }

    private var searchResults: [Note] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }

        return activeNotes.filter {
            $0.title.localizedCaseInsensitiveContains(query)
                || $0.body.localizedCaseInsensitiveContains(query)
                || $0.tagsText.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    if search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        dashboard
                    } else {
                        searchContent
                    }
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("TideNotes")
            .searchable(text: $search, prompt: "Search notes")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
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
        .tint(.blue)
    }

    private var dashboard: some View {
        VStack(alignment: .leading, spacing: 24) {
            if activeNotes.isEmpty {
                welcomeCard
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Library")
                    .font(.headline)
                    .padding(.horizontal, 2)

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ],
                    spacing: 12
                ) {
                    NavigationLink {
                        NoteListView(mode: .all)
                    } label: {
                        SmartCard(
                            icon: "note.text",
                            title: "All Notes",
                            count: activeNotes.count,
                            detail: "Everything"
                        )
                    }

                    NavigationLink {
                        NoteListView(mode: .pinned)
                    } label: {
                        SmartCard(
                            icon: "pin.fill",
                            title: "Pinned",
                            count: pinnedCount,
                            detail: "Keep close"
                        )
                    }

                    NavigationLink {
                        NoteListView(mode: .today)
                    } label: {
                        SmartCard(
                            icon: "clock.fill",
                            title: "Today",
                            count: todayCount,
                            detail: "Recently touched"
                        )
                    }

                    NavigationLink {
                        NoteListView(mode: .attachments)
                    } label: {
                        SmartCard(
                            icon: "paperclip",
                            title: "Attachments",
                            count: attachmentsCount,
                            detail: "Photos & drawings"
                        )
                    }
                }
            }

            if !activeNotes.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Recent")
                            .font(.headline)

                        Spacer()

                        NavigationLink("See All") {
                            NoteListView(mode: .all)
                        }
                        .font(.subheadline.weight(.semibold))
                    }

                    VStack(spacing: 0) {
                        ForEach(Array(activeNotes.prefix(5))) { note in
                            NavigationLink {
                                NoteEditorView(note: note)
                            } label: {
                                RecentNoteRow(note: note)
                            }
                            .buttonStyle(.plain)

                            Divider()
                                .padding(.leading, 50)
                        }
                    }
                    .background(
                        Color(uiColor: .secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Folders")
                        .font(.headline)

                    Spacer()

                    Button {
                        showingNewFolder = true
                    } label: {
                        Label("New", systemImage: "plus")
                            .font(.subheadline.weight(.semibold))
                    }
                }

                if folders.isEmpty {
                    Button {
                        showingNewFolder = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "folder.badge.plus")
                                .font(.title3)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Create a folder")
                                    .font(.subheadline.weight(.semibold))
                                Text("Keep school, ideas and projects separate.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                        .padding(16)
                        .background(
                            Color(uiColor: .secondarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)
                        ],
                        spacing: 12
                    ) {
                        ForEach(folders) { folder in
                            NavigationLink {
                                NoteListView(mode: .folder(folder))
                            } label: {
                                FolderCard(
                                    name: folder.name,
                                    count: activeNotes.filter { $0.folder?.id == folder.id }.count
                                )
                            }
                            .buttonStyle(.plain)
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
                        }
                    }
                }
            }

            if deletedCount > 0 {
                NavigationLink {
                    NoteListView(mode: .recentlyDeleted)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "trash")
                            .frame(width: 28)
                            .foregroundStyle(.secondary)

                        Text("Recently Deleted")
                            .font(.subheadline.weight(.semibold))

                        Spacer()

                        Text("\(deletedCount)")
                            .foregroundStyle(.secondary)

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(16)
                    .background(
                        Color(uiColor: .secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 32)
    }

    private var searchContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if searchResults.isEmpty {
                ContentUnavailableView.search(text: search)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
            } else {
                Text("\(searchResults.count) result\(searchResults.count == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                VStack(spacing: 0) {
                    ForEach(searchResults) { note in
                        NavigationLink {
                            NoteEditorView(note: note)
                        } label: {
                            RecentNoteRow(note: note)
                        }
                        .buttonStyle(.plain)

                        Divider()
                            .padding(.leading, 50)
                    }
                }
                .background(
                    Color(uiColor: .secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var welcomeCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: "wave.3.right.circle.fill")
                .font(.system(size: 38))
                .foregroundStyle(.blue)

            Text("Your notes, without the noise.")
                .font(.title2.bold())

            Text("TideNotes saves locally, works offline, and stays quick even when your brain has seventeen tabs open.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                createAndOpenNote()
            } label: {
                Label("Create your first note", systemImage: "square.and.pencil")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(18)
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
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

private struct SmartCard: View {
    let icon: String
    let title: String
    let count: Int
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.blue)

                Spacer()

                Text("\(count)")
                    .font(.title3.bold())
                    .foregroundStyle(.primary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .padding(15)
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
    }
}

private struct FolderCard: View {
    let name: String
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "folder.fill")
                .font(.title2)
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text("\(count) note\(count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 90, alignment: .leading)
        .padding(15)
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
    }
}

private struct RecentNoteRow: View {
    let note: Note

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.blue.opacity(0.10))

                Image(systemName: note.isLocked ? "lock.fill" : "note.text")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.blue)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(note.displayTitle)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)

                    if note.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }

                Text(note.isLocked ? "Locked Note" : note.preview)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(note.updatedAt, format: .dateTime.day().month())
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }
}
