import Foundation
import Testing
@testable import QuartzKit

private struct Sample: Codable, Equatable {
    let title: String
    let value: Int
}

@Test("Un premier lancement reste distinct d’une erreur de lecture")
func missingFileIsNotTreatedAsAnError() throws {
    try withTemporaryStore { store in
        guard case .missing = store.load() else {
            Issue.record("Un premier lancement doit être reconnu comme un stockage absent.")
            return
        }
    }
}

@Test("La deuxième écriture conserve la version valide précédente")
func secondSaveKeepsPreviousValidVersion() throws {
    try withTemporaryStore { store in
        let first = Sample(title: "Première", value: 1)
        let second = Sample(title: "Deuxième", value: 2)

        try store.save(first).get()
        try store.save(second).get()

        let backup = try decode(Sample.self, from: store.backupURL)
        let current = try decode(Sample.self, from: store.fileURL)
        #expect(backup == first)
        #expect(current == second)
    }
}

@Test("Un fichier principal corrompu est isolé puis restauré")
func corruptPrimaryIsQuarantinedAndBackupIsRestored() throws {
    try withTemporaryStore { store in
        let safe = Sample(title: "Version sûre", value: 1)
        let latest = Sample(title: "Version récente", value: 2)

        try store.save(safe).get()
        try store.save(latest).get()
        try Data("{fichier cassé".utf8).write(to: store.fileURL, options: .atomic)

        guard case let .recovered(value, quarantinedFileURL) = store.load() else {
            Issue.record("La sauvegarde précédente aurait dû être restaurée.")
            return
        }

        #expect(value == safe)
        #expect(quarantinedFileURL != nil)
        if let quarantinedFileURL {
            #expect(FileManager.default.fileExists(atPath: quarantinedFileURL.path))
        }
        #expect(try decode(Sample.self, from: store.fileURL) == safe)
    }
}

@Test("Une corruption sans sauvegarde reste récupérable manuellement")
func corruptPrimaryWithoutBackupIsPreservedAndReported() throws {
    try withTemporaryStore { store in
        let damaged = Data("{illisible".utf8)
        try damaged.write(to: store.fileURL, options: .atomic)

        guard case let .failed(error) = store.load() else {
            Issue.record("Une corruption sans sauvegarde ne doit pas devenir un stockage vide.")
            return
        }

        #expect(error.recoveryFileURL != nil)
        #expect(try Data(contentsOf: store.fileURL) == damaged)
        if let recoveryFileURL = error.recoveryFileURL {
            #expect(try Data(contentsOf: recoveryFileURL) == damaged)
        }
    }
}

@Test("Une nouvelle sauvegarde ne remplace jamais le bon secours par un fichier corrompu")
func savingAfterCorruptionDoesNotReplaceTheGoodBackup() throws {
    try withTemporaryStore { store in
        let safe = Sample(title: "Sauvegarde", value: 1)
        let current = Sample(title: "Courante", value: 2)
        let replacement = Sample(title: "Nouvelle", value: 3)

        try store.save(safe).get()
        try store.save(current).get()
        try Data("cassé".utf8).write(to: store.fileURL, options: .atomic)
        try store.save(replacement).get()

        #expect(try decode(Sample.self, from: store.backupURL) == safe)
        #expect(try decode(Sample.self, from: store.fileURL) == replacement)
    }
}

private func withTemporaryStore(
    _ body: (RecoverableJSONStore<Sample>) throws -> Void
) throws {
    let directoryURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("QuartzTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let store = RecoverableJSONStore<Sample>(
        fileURL: directoryURL.appendingPathComponent("sample.json")
    )
    try body(store)
}

private func decode<Value: Decodable>(_ type: Value.Type, from url: URL) throws -> Value {
    try JSONDecoder().decode(type, from: Data(contentsOf: url))
}
