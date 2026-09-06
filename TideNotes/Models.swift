import Foundation
import SwiftData

@Model
final class NoteFolder {
    var id: UUID
    var name: String
    var createdAt: Date

    init(name: String, createdAt: Date = .now) {
        self.id = UUID()
        self.name = name
        self.createdAt = createdAt
    }
}

@Model
final class Note {
    var id: UUID
    var title: String
    var body: String
    var createdAt: Date
    var updatedAt: Date
    var isPinned: Bool
    var deletedAt: Date?
    var folder: NoteFolder?
    var tagsText: String
    var isLocked: Bool

    @Attribute(.externalStorage) var photoData: Data?
    @Attribute(.externalStorage) var drawingData: Data?

    init(
        title: String = "",
        body: String = "",
        folder: NoteFolder? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.body = body
        self.createdAt = .now
        self.updatedAt = .now
        self.isPinned = false
        self.deletedAt = nil
        self.folder = folder
        self.tagsText = ""
        self.isLocked = false
        self.photoData = nil
        self.drawingData = nil
    }

    var isDeleted: Bool { deletedAt != nil }

    var displayTitle: String {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.isEmpty { return clean }

        let firstBodyLine = body
            .split(separator: "\n", omittingEmptySubsequences: true)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return (firstBodyLine?.isEmpty == false) ? firstBodyLine! : "New Note"
    }

    var preview: String {
        let clean = body
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? "No additional text" : clean
    }

    var tags: [String] {
        tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var wordCount: Int {
        body.split { $0.isWhitespace || $0.isNewline }.count
    }

    func touch() {
        updatedAt = .now
    }
}
