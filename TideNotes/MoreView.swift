import SwiftUI
import SwiftData

struct MoreView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Note.updatedAt, order: .reverse) private var notes: [Note]

    private var deleted: [Note] { notes.filter(\.isDeleted) }

    var body: some View {
        List {
            Section("TideNotes") {
                Label("On My iPhone", systemImage: "iphone")
                Label("Offline First", systemImage: "wifi.slash")
            }

            Section("Recently Deleted") {
                if deleted.isEmpty {
                    Text("No Recently Deleted notes")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(deleted) { note in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(note.displayTitle)
                                    .font(.headline)
                                Text(note.preview)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Menu {
                                Button("Recover") {
                                    note.isDeleted = false
                                    note.updatedAt = .now
                                }
                                Button("Delete Forever", role: .destructive) {
                                    context.delete(note)
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Folders")
    }
}
