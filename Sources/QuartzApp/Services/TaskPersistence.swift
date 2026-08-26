import QuartzKit
import Foundation

@MainActor
final class TaskPersistence {
    private let store: RecoverableJSONStore<[TodoTask]>

    var dataDirectoryURL: URL {
        store.fileURL.deletingLastPathComponent()
    }

    init(fileManager: FileManager = .default) {
        let directory = QuartzPaths.applicationSupportDirectory(fileManager: fileManager)
        store = RecoverableJSONStore(
            fileURL: directory.appendingPathComponent("tasks.json"),
            fileManager: fileManager,
            configureEncoder: { $0.dateEncodingStrategy = .iso8601 },
            configureDecoder: { $0.dateDecodingStrategy = .iso8601 }
        )
    }

    func load() -> RecoverableJSONLoad<[TodoTask]> {
        store.load()
    }

    func save(_ tasks: [TodoTask]) -> JSONFileStoreFailure? {
        switch store.save(tasks) {
        case .success:
            nil
        case let .failure(error):
            error
        }
    }
}
