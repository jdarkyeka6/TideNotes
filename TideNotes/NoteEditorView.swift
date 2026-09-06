import SwiftUI
import SwiftData

struct NoteEditorView: View {
    @Environment(\.modelContext) private var context
    @Bindable var note: Note
    @FocusState private var bodyFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            TextField("Title", text: $note.title, axis: .vertical)
                .font(.system(size: 28, weight: .bold))
                .padding(.horizontal)
                .padding(.top, 10)
                .onChange(of: note.title) { _, _ in touch() }

            TextEditor(text: $note.body)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 12)
                .focused($bodyFocused)
                .onChange(of: note.body) { _, _ in touch() }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Button {
                    note.isPinned.toggle()
                    touch()
                } label: {
                    Image(systemName: note.isPinned ? "pin.fill" : "pin")
                }

                Spacer()

                Button {
                    insertChecklist()
                } label: {
                    Image(systemName: "checklist")
                }

                Spacer()

                ShareLink(item: shareText) {
                    Image(systemName: "square.and.arrow.up")
                }

                Spacer()

                Menu {
                    Button(role: .destructive) {
                        note.isDeleted = true
                        touch()
                    } label: {
                        Label("Move to Recently Deleted", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .onAppear { bodyFocused = note.title.isEmpty && note.body.isEmpty }
    }

    private var shareText: String {
        [note.title, note.body].filter { !$0.isEmpty }.joined(separator: "\n\n")
    }

    private func touch() {
        note.updatedAt = .now
        try? context.save()
    }

    private func insertChecklist() {
        if !note.body.isEmpty && !note.body.hasSuffix("\n") { note.body += "\n" }
        note.body += "☐ "
        touch()
        bodyFocused = true
    }
}
