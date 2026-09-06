import SwiftUI
import SwiftData

@main
struct TideNotesApp: App {
    var body: some Scene {
        WindowGroup {
            NotesHomeView()
        }
        .modelContainer(for: [Note.self, NoteFolder.self])
    }
}
