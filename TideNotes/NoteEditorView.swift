import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct NoteEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \NoteFolder.createdAt) private var folders: [NoteFolder]

    @Bindable var note: Note

    @State private var bodyFocused = false
    @State private var formatCommand: RichTextCommand?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showingDrawing = false
    @State private var unlocked = false
    @State private var unlocking = false
    @State private var lockError = false
    @State private var showingTags = false
    @State private var draftTags = ""

    var body: some View {
        Group {
            if note.isLocked && !unlocked {
                lockedView
            } else {
                editor
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if !note.isLocked {
                unlocked = true
            } else if !unlocked {
                await unlock()
            }
        }
        .alert("Couldn’t Unlock", isPresented: $lockError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Face ID, Touch ID, or your device passcode could not unlock this note.")
        }
        .sheet(isPresented: $showingDrawing) {
            DrawingEditorSheet(data: $note.drawingData) {
                save()
            }
        }
        .sheet(isPresented: $showingTags) {
            tagsSheet
        }
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        note.photoData = data
                        save()
                    }
                }
            }
        }
    }

    private var editor: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    TextField("Title", text: $note.title, axis: .vertical)
                        .font(.system(size: 30, weight: .bold))
                        .textInputAutocapitalization(.sentences)
                        .onChange(of: note.title) { _, _ in save() }

                    if let photoData = note.photoData,
                       let image = UIImage(data: photoData) {
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                            Button {
                                note.photoData = nil
                                save()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.white, .black.opacity(0.55))
                            }
                            .padding(8)
                        }
                    }

                    if let drawingData = note.drawingData,
                       let preview = DrawingPreview.image(from: drawingData) {
                        ZStack(alignment: .topTrailing) {
                            Button {
                                showingDrawing = true
                            } label: {
                                Image(uiImage: preview)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: .infinity)
                                    .background(Color(uiColor: .secondarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .buttonStyle(.plain)

                            Button {
                                note.drawingData = nil
                                save()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.white, .black.opacity(0.55))
                            }
                            .padding(8)
                        }
                    }

                    RichTextEditor(
                        text: $note.body,
                        rtfData: $note.richTextData,
                        command: $formatCommand,
                        isFocused: $bodyFocused,
                        onChange: save
                    )
                    .frame(minHeight: 360, idealHeight: 440, maxHeight: 560)

                    if !note.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(note.tags, id: \.self) { tag in
                                    Text("#\(tag)")
                                        .font(.caption.weight(.medium))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(.thinMaterial, in: Capsule())
                                }
                            }
                        }
                    }

                    Text("\(note.wordCount) words")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 80)
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    Section("Move") {
                        Button {
                            note.folder = nil
                            save()
                        } label: {
                            Label("All Notes", systemImage: note.folder == nil ? "checkmark" : "note.text")
                        }

                        ForEach(folders) { folder in
                            Button {
                                note.folder = folder
                                save()
                            } label: {
                                Label(folder.name, systemImage: note.folder?.id == folder.id ? "checkmark" : "folder")
                            }
                        }
                    }

                    Section {
                        Button {
                            note.isPinned.toggle()
                            save()
                        } label: {
                            Label(note.isPinned ? "Unpin" : "Pin", systemImage: note.isPinned ? "pin.slash" : "pin")
                        }

                        Button {
                            draftTags = note.tagsText
                            showingTags = true
                        } label: {
                            Label("Tags", systemImage: "number")
                        }

                        Button {
                            toggleLock()
                        } label: {
                            Label(note.isLocked ? "Remove Lock" : "Lock Note", systemImage: note.isLocked ? "lock.open" : "lock")
                        }
                    }

                    Section {
                        ShareLink(item: shareText) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }

                        Button(role: .destructive) {
                            note.deletedAt = .now
                            save()
                            dismiss()
                        } label: {
                            Label("Move to Recently Deleted", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }

            ToolbarItemGroup(placement: .bottomBar) {
                Button {
                    send(.checklist)
                } label: {
                    Image(systemName: "checklist")
                }

                Spacer()

                Menu {
                    Button("Heading") { send(.heading) }
                    Button("Body") { send(.body) }
                    Divider()
                    Button("Bold") { send(.bold) }
                    Button("Italic") { send(.italic) }
                    Divider()
                    Button("Bullet List") { send(.bullet) }
                    Button("Numbered List") { send(.numbered) }
                    Button("Checklist") { send(.checklist) }
                    Button("Quote") { send(.quote) }
                } label: {
                    Image(systemName: "textformat")
                }

                Spacer()

                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Image(systemName: "photo")
                }

                Spacer()

                Button {
                    showingDrawing = true
                } label: {
                    Image(systemName: "pencil.tip.crop.circle")
                }

                Spacer()

                Button {
                    bodyFocused = false
                } label: {
                    Image(systemName: "keyboard.chevron.compact.down")
                }
            }
        }
        .onAppear {
            if note.title.isEmpty && note.body.isEmpty {
                bodyFocused = true
            }
        }
    }

    private var lockedView: some View {
        ContentUnavailableView {
            Label("Locked Note", systemImage: "lock.fill")
        } description: {
            Text("Authenticate to open this note.")
        } actions: {
            Button(unlocking ? "Unlocking…" : "Unlock") {
                Task { await unlock() }
            }
            .disabled(unlocking)
        }
    }

    private var tagsSheet: some View {
        NavigationStack {
            Form {
                Section("Tags") {
                    TextField("school, ideas, important", text: $draftTags)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Section {
                    Text("Separate tags with commas.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingTags = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        note.tagsText = draftTags
                        save()
                        showingTags = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var shareText: String {
        [note.title, note.body]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n\n")
    }

    private func send(_ kind: RichTextCommand.Kind) {
        formatCommand = RichTextCommand(kind: kind)
        bodyFocused = true
    }

    private func save() {
        note.touch()
        try? context.save()
    }

    private func toggleLock() {
        note.isLocked.toggle()
        unlocked = true
        save()
    }

    @MainActor
    private func unlock() async {
        unlocking = true
        let success = await NoteLock.authenticate(reason: "Unlock this TideNote")
        unlocking = false
        if success {
            unlocked = true
        } else {
            lockError = true
        }
    }
}
