import Foundation
import SwiftData

@Model
final class NoteFolder {
    var name: String
    var createdAt: Date

    init(name: String, createdAt: Date = .now) {
        self.name = name
        self.createdAt = createdAt
    }
}

@Model
final class Note {
    var title: String
    var body: String
    var createdAt: Date
    var updatedAt: Date
    var isPinned: Bool
    var isDeleted: Bool
    var folder: NoteFolder?

    init(title: String = "", body: String = "", folder: NoteFolder? = nil) {
        self.title = title
        self.body = body
        self.createdAt = .now
        self.updatedAt = .now
        self.isPinned = false
        self.isDeleted = false
        self.folder = folder
    }

    var displayTitle: String {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? "New Note" : clean
    }

    var preview: String {
        let clean = body.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? "No additional text" : clean.replacingOccurrences(of: "\n", with: " ")
    }
}
