import QuartzKit
import Foundation

@MainActor
final class PostItPersistence {
    private let store: RecoverableJSONStore<[PostItNote]>

    init(fileManager: FileManager = .default) {
        let directory = QuartzPaths.applicationSupportDirectory(fileManager: fileManager)
        store = RecoverableJSONStore(
            fileURL: directory.appendingPathComponent("post-its.json"),
            fileManager: fileManager,
            configureEncoder: { $0.dateEncodingStrategy = .iso8601 },
            configureDecoder: { $0.dateDecodingStrategy = .iso8601 }
        )
    }

    func load() -> RecoverableJSONLoad<[PostItNote]> {
        switch store.load() {
        case .missing:
            .missing
        case let .loaded(notes):
            .loaded(normalize(notes))
        case let .recovered(notes, quarantinedFileURL):
            .recovered(normalize(notes), quarantinedFileURL: quarantinedFileURL)
        case let .failed(error):
            .failed(error)
        }
    }

    func save(_ notes: [PostItNote]) -> JSONFileStoreFailure? {
        switch store.save(notes) {
        case .success:
            nil
        case let .failure(error):
            error
        }
    }

    private func normalize(_ notes: [PostItNote]) -> [PostItNote] {
        notes.map { note in
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
    }
}
