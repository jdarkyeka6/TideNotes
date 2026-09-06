import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query private var notes: [Note]
    @Query private var folders: [NoteFolder]

    @State private var confirmEmptyTrash = false

    private var activeNotes: [Note] { notes.filter { !$0.isDeleted } }
    private var deletedNotes: [Note] { notes.filter(\.isDeleted) }

    var body: some View {
        List {
            Section("Library") {
                LabeledContent("Notes", value: "\(activeNotes.count)")
                LabeledContent("Folders", value: "\(folders.count)")
                LabeledContent("Deleted", value: "\(deletedNotes.count)")
            }

            Section("Privacy") {
                Label("Notes are stored on this iPhone", systemImage: "iphone.and.arrow.forward")
                Label("Locked notes use device authentication", systemImage: "faceid")
                Label("No TideNotes account required", systemImage: "person.crop.circle.badge.checkmark")
            }

            Section("Storage") {
                Button("Empty Recently Deleted", role: .destructive) {
                    confirmEmptyTrash = true
                }
                .disabled(deletedNotes.isEmpty)
            }

            Section("About") {
                LabeledContent("App", value: "TideNotes")
                LabeledContent("Version", value: "0.1 (1)")
                Text("A fast, offline-first notes app built for the Tide ecosystem.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
        .alert("Empty Recently Deleted?", isPresented: $confirmEmptyTrash) {
            Button("Cancel", role: .cancel) { }
            Button("Delete Forever", role: .destructive) {
                emptyTrash()
            }
        } message: {
            Text("This permanently deletes every note in Recently Deleted.")
        }
    }

    private func emptyTrash() {
        for note in deletedNotes {
            context.delete(note)
        }
        try? context.save()
    }
}
