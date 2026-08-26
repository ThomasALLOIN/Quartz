import Foundation

public struct JSONFileStoreFailure: Error, LocalizedError {
    public let fileURL: URL
    public let operation: String
    public let details: String
    public let recoveryFileURL: URL?

    public init(
        fileURL: URL,
        operation: String,
        details: String,
        recoveryFileURL: URL? = nil
    ) {
        self.fileURL = fileURL
        self.operation = operation
        self.details = details
        self.recoveryFileURL = recoveryFileURL
    }

    public var errorDescription: String? {
        "Impossible de \(operation) \(fileURL.lastPathComponent). \(details)"
    }
}

public enum RecoverableJSONLoad<Value> {
    case missing
    case loaded(Value)
    case recovered(Value, quarantinedFileURL: URL?)
    case failed(JSONFileStoreFailure)
}

/// Petit stockage JSON local qui conserve toujours une version précédente valide.
/// Un fichier illisible est copié dans `Recovery` avant toute nouvelle écriture.
public final class RecoverableJSONStore<Value: Codable> {
    public let fileURL: URL
    public let backupURL: URL
    public let recoveryDirectoryURL: URL

    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        fileURL: URL,
        fileManager: FileManager = .default,
        configureEncoder: (JSONEncoder) -> Void = { _ in },
        configureDecoder: (JSONDecoder) -> Void = { _ in }
    ) {
        self.fileURL = fileURL
        self.fileManager = fileManager

        let directory = fileURL.deletingLastPathComponent()
        let stem = fileURL.deletingPathExtension().lastPathComponent
        let fileExtension = fileURL.pathExtension
        let backupName = fileExtension.isEmpty
            ? "\(stem).backup"
            : "\(stem).backup.\(fileExtension)"
        backupURL = directory.appendingPathComponent(backupName)
        recoveryDirectoryURL = directory.appendingPathComponent("Recovery", isDirectory: true)

        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        configureEncoder(encoder)

        decoder = JSONDecoder()
        configureDecoder(decoder)
    }

    public func load() -> RecoverableJSONLoad<Value> {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return loadOrphanedBackup()
        }

        do {
            let data = try Data(contentsOf: fileURL)
            return .loaded(try decoder.decode(Value.self, from: data))
        } catch {
            let quarantinedURL = quarantinePrimaryFile()
            guard fileManager.fileExists(atPath: backupURL.path) else {
                return .failed(
                    failure(
                        operation: "lire",
                        underlying: error,
                        recoveryFileURL: quarantinedURL
                    )
                )
            }

            do {
                let backupData = try Data(contentsOf: backupURL)
                let value = try decoder.decode(Value.self, from: backupData)
                try? backupData.write(to: fileURL, options: .atomic)
                return .recovered(value, quarantinedFileURL: quarantinedURL)
            } catch {
                return .failed(
                    failure(
                        operation: "récupérer depuis la sauvegarde",
                        underlying: error,
                        recoveryFileURL: quarantinedURL
                    )
                )
            }
        }
    }

    @discardableResult
    public func save(_ value: Value) -> Result<Void, JSONFileStoreFailure> {
        do {
            let directory = fileURL.deletingLastPathComponent()
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            let encoded = try encoder.encode(value)

            if fileManager.fileExists(atPath: fileURL.path) {
                if
                    let currentData = try? Data(contentsOf: fileURL),
                    (try? decoder.decode(Value.self, from: currentData)) != nil
                {
                    try currentData.write(to: backupURL, options: .atomic)
                } else {
                    _ = quarantinePrimaryFile()
                }
            }

            try encoded.write(to: fileURL, options: .atomic)
            return .success(())
        } catch {
            return .failure(failure(operation: "enregistrer", underlying: error))
        }
    }

    private func loadOrphanedBackup() -> RecoverableJSONLoad<Value> {
        guard fileManager.fileExists(atPath: backupURL.path) else { return .missing }
        do {
            let backupData = try Data(contentsOf: backupURL)
            let value = try decoder.decode(Value.self, from: backupData)
            try? backupData.write(to: fileURL, options: .atomic)
            return .recovered(value, quarantinedFileURL: nil)
        } catch {
            return .failed(
                failure(operation: "récupérer depuis la sauvegarde", underlying: error)
            )
        }
    }

    private func quarantinePrimaryFile() -> URL? {
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        do {
            try fileManager.createDirectory(
                at: recoveryDirectoryURL,
                withIntermediateDirectories: true
            )
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyyMMdd-HHmmss"
            let stamp = formatter.string(from: Date())
            let suffix = UUID().uuidString.prefix(8)
            let recoveryURL = recoveryDirectoryURL.appendingPathComponent(
                "\(fileURL.deletingPathExtension().lastPathComponent)-corrompu-\(stamp)-\(suffix).json"
            )
            try fileManager.copyItem(at: fileURL, to: recoveryURL)
            return recoveryURL
        } catch {
            return nil
        }
    }

    private func failure(
        operation: String,
        underlying: Error,
        recoveryFileURL: URL? = nil
    ) -> JSONFileStoreFailure {
        JSONFileStoreFailure(
            fileURL: fileURL,
            operation: operation,
            details: underlying.localizedDescription,
            recoveryFileURL: recoveryFileURL
        )
    }
}
