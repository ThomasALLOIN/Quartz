import QuartzKit
import Foundation

@MainActor
final class TaskPersistence {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileManager: FileManager = .default) {
        let directory = QuartzPaths.applicationSupportDirectory(fileManager: fileManager)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("tasks.json")

        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func load() -> [TodoTask]? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        do {
            return try decoder.decode([TodoTask].self, from: Data(contentsOf: fileURL))
        } catch {
            assertionFailure("Impossible de lire les tâches : \(error)")
            return nil
        }
    }

    func save(_ tasks: [TodoTask]) {
        do {
            try encoder.encode(tasks).write(to: fileURL, options: .atomic)
        } catch {
            assertionFailure("Impossible d’enregistrer les tâches : \(error)")
        }
    }
}
