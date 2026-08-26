import QuartzKit
import Foundation

@MainActor
final class PostItPersistence {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileManager: FileManager = .default) {
        let directory = QuartzPaths.applicationSupportDirectory(fileManager: fileManager)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("post-its.json")

        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func load() -> [PostItNote] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        do {
            let storedNotes = try decoder.decode([PostItNote].self, from: Data(contentsOf: fileURL))
            let normalizedNotes = storedNotes.map { note in
                var normalizedNote = note
                switch normalizedNote.scope {
                case .persistent:
                    normalizedNote.tone = .parchment
                    normalizedNote.dayKey = nil
                case .daily:
                    normalizedNote.tone = .sage
                    if normalizedNote.dayKey == nil {
                        normalizedNote.dayKey = LocalDay.key(
                            for: normalizedNote.createdAt,
                            calendar: .french
                        )
                    }
                }
                return normalizedNote
            }
            if normalizedNotes != storedNotes {
                save(normalizedNotes)
            }
            return normalizedNotes
        } catch {
            assertionFailure("Impossible de lire les post-it : \(error)")
            return []
        }
    }

    func save(_ notes: [PostItNote]) {
        do {
            try encoder.encode(notes).write(to: fileURL, options: .atomic)
        } catch {
            assertionFailure("Impossible d’enregistrer les post-it : \(error)")
        }
    }
}
