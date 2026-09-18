import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query private var notes: [Note]
    @Query private var folders: [NoteFolder]

    @State private var confirmEmptyTrash = false

    private var activeNotes: [Note] { notes.filter { !$0.isDeleted } }
    private var deletedNotes: [Note] { notes.filter(\.isDeleted) }

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.2"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.red.gradient)

                        Image(systemName: "note.text")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                    }
                    .frame(width: 56, height: 56)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("TideNotes")
                            .font(.headline)

                        Text("Fast notes. Local first.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Library") {
                LabeledContent("Notes", value: "\(activeNotes.count)")
                LabeledContent("Folders", value: "\(folders.count)")
                LabeledContent("Deleted", value: "\(deletedNotes.count)")
            }

            Section("Privacy") {
                Label("Stored locally on this iPhone", systemImage: "iphone")
                Label("Locked notes use device authentication", systemImage: "faceid")
                Label("No account required", systemImage: "person.crop.circle.badge.checkmark")
            }

            Section("Storage") {
                Button("Empty Recently Deleted", role: .destructive) {
                    confirmEmptyTrash = true
                }
                .disabled(deletedNotes.isEmpty)
            }

            Section("About") {
                LabeledContent("Version", value: versionText)
                Text("TideNotes is an offline-first notes app built for the Tide ecosystem.")
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
