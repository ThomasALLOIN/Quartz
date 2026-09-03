import Foundation

public enum QuartzPaths {
    public static func applicationSupportDirectory(
        fileManager: FileManager = .default,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        applicationSupportRoot: URL? = nil
    ) -> URL {
        if let override = environment["QUARTZ_SUPPORT_DIR"], !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true)
        }

        let root = applicationSupportRoot
            ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let current = root.appendingPathComponent("Quartz", isDirectory: true)
        migrateLegacyDataIfNeeded(in: root, to: current, fileManager: fileManager)
        return current
    }

    /// Récupère une seule fois les données produites avant le renommage complet.
    /// Les fichiers Quartz déjà présents ont toujours priorité.
    private static func migrateLegacyDataIfNeeded(
        in root: URL,
        to current: URL,
        fileManager: FileManager
    ) {
        let legacy = root.appendingPathComponent("EcrinPreview", isDirectory: true)
        guard fileManager.fileExists(atPath: legacy.path) else { return }

        if !fileManager.fileExists(atPath: current.path) {
            try? fileManager.moveItem(at: legacy, to: current)
            return
        }

        guard let legacyItems = try? fileManager.contentsOfDirectory(
            at: legacy,
            includingPropertiesForKeys: nil
        ) else { return }
        for item in legacyItems {
            let destination = current.appendingPathComponent(item.lastPathComponent)
            guard !fileManager.fileExists(atPath: destination.path) else { continue }
            try? fileManager.moveItem(at: item, to: destination)
        }
    }
}

public struct ExternalSubtaskDraft: Codable, Equatable, Sendable {
    public var title: String
    public var description: String?

    public init(title: String, description: String? = nil) {
        self.title = title
        self.description = description
    }
}

/// Détermine où une demande d'agent est affichée. Les anciennes demandes
/// continuent d'utiliser la destination post-it active de l'application.
public enum ExternalTaskDestination: String, Codable, Equatable, Sendable {
    case task
    case activePostIt
}

public struct ExternalTaskRequest: Codable, Equatable, Identifiable, Sendable {
    public static let currentVersion = 1

    public var version: Int
    public var id: UUID
    public var createdAt: Date
    public var source: String?
    public var destination: ExternalTaskDestination
    public var title: String
    public var startDate: Date
    public var dueMinutes: Int?
    public var recurrence: RecurrenceRule
    public var reminder: ReminderOption
    public var notes: String
    public var subtasks: [ExternalSubtaskDraft]

    public init(
        version: Int = ExternalTaskRequest.currentVersion,
        id: UUID = UUID(),
        createdAt: Date = Date(),
        source: String? = nil,
        destination: ExternalTaskDestination = .activePostIt,
        title: String,
        startDate: Date,
        dueMinutes: Int? = nil,
        recurrence: RecurrenceRule = .none,
        reminder: ReminderOption = .none,
        notes: String = "",
        subtasks: [ExternalSubtaskDraft] = []
    ) {
        self.version = version
        self.id = id
        self.createdAt = createdAt
        self.source = source
        self.destination = destination
        self.title = title
        self.startDate = startDate
        self.dueMinutes = dueMinutes
        self.recurrence = recurrence
        self.reminder = reminder
        self.notes = notes
        self.subtasks = subtasks
    }

    public func makeTask(calendar: Calendar = .french) throws -> TodoTask {
        guard version == Self.currentVersion else {
            throw ExternalTaskValidationError.unsupportedVersion(version)
        }

        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { throw ExternalTaskValidationError.emptyTitle }
        guard cleanTitle.count <= 240 else { throw ExternalTaskValidationError.titleTooLong }
        guard notes.count <= 10_000 else { throw ExternalTaskValidationError.notesTooLong }
        guard subtasks.count <= 100 else { throw ExternalTaskValidationError.tooManySubtasks }

        if let dueMinutes, !(0..<24 * 60).contains(dueMinutes) {
            throw ExternalTaskValidationError.invalidDueMinutes
        }
        if reminder != .none, dueMinutes == nil {
            throw ExternalTaskValidationError.reminderRequiresTime
        }
        let cleanSubtasks = try subtasks.map { subtask in
            let cleanTitle = subtask.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanTitle.isEmpty else { throw ExternalTaskValidationError.emptySubtaskTitle }
            guard cleanTitle.count <= 240 else { throw ExternalTaskValidationError.subtaskTitleTooLong }
            let cleanDescription = subtask.description?.trimmingCharacters(in: .whitespacesAndNewlines)
            guard (cleanDescription?.count ?? 0) <= 2_000 else {
                throw ExternalTaskValidationError.subtaskDescriptionTooLong
            }
            return TodoSubtask(
                title: cleanTitle,
                description: cleanDescription?.isEmpty == true ? nil : cleanDescription
            )
        }

        return TodoTask(
            id: id,
            title: cleanTitle,
            startDate: calendar.startOfDay(for: startDate),
            dueMinutes: dueMinutes,
            recurrence: recurrence,
            reminder: reminder,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            subtasks: cleanSubtasks,
            createdAt: createdAt
        )
    }

    private enum CodingKeys: String, CodingKey {
        case version, id, createdAt, source, destination, title, startDate
        case dueMinutes, recurrence, reminder, notes, subtasks
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        version = try values.decode(Int.self, forKey: .version)
        id = try values.decode(UUID.self, forKey: .id)
        createdAt = try values.decode(Date.self, forKey: .createdAt)
        source = try values.decodeIfPresent(String.self, forKey: .source)
        destination = try values.decodeIfPresent(ExternalTaskDestination.self, forKey: .destination)
            ?? .activePostIt
        title = try values.decode(String.self, forKey: .title)
        startDate = try values.decode(Date.self, forKey: .startDate)
        dueMinutes = try values.decodeIfPresent(Int.self, forKey: .dueMinutes)
        recurrence = try values.decode(RecurrenceRule.self, forKey: .recurrence)
        reminder = try values.decode(ReminderOption.self, forKey: .reminder)
        notes = try values.decode(String.self, forKey: .notes)
        subtasks = try values.decode([ExternalSubtaskDraft].self, forKey: .subtasks)
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(version, forKey: .version)
        try values.encode(id, forKey: .id)
        try values.encode(createdAt, forKey: .createdAt)
        try values.encodeIfPresent(source, forKey: .source)
        try values.encode(destination, forKey: .destination)
        try values.encode(title, forKey: .title)
        try values.encode(startDate, forKey: .startDate)
        try values.encodeIfPresent(dueMinutes, forKey: .dueMinutes)
        try values.encode(recurrence, forKey: .recurrence)
        try values.encode(reminder, forKey: .reminder)
        try values.encode(notes, forKey: .notes)
        try values.encode(subtasks, forKey: .subtasks)
    }
}

public enum ExternalTaskValidationError: Error, Equatable, LocalizedError, Sendable {
    case unsupportedVersion(Int)
    case emptyTitle
    case titleTooLong
    case notesTooLong
    case invalidDueMinutes
    case reminderRequiresTime
    case tooManySubtasks
    case emptySubtaskTitle
    case subtaskTitleTooLong
    case subtaskDescriptionTooLong

    public var errorDescription: String? {
        switch self {
        case let .unsupportedVersion(version): "Version de requête non prise en charge : \(version)"
        case .emptyTitle: "Le titre de la tâche est vide"
        case .titleTooLong: "Le titre dépasse 240 caractères"
        case .notesTooLong: "Les notes dépassent 10 000 caractères"
        case .invalidDueMinutes: "L’heure doit être comprise entre 00:00 et 23:59"
        case .reminderRequiresTime: "Un rappel nécessite une heure"
        case .tooManySubtasks: "Une tâche ne peut pas dépasser 100 sous-tâches"
        case .emptySubtaskTitle: "Le titre d’une sous-tâche est vide"
        case .subtaskTitleTooLong: "Le titre d’une sous-tâche dépasse 240 caractères"
        case .subtaskDescriptionTooLong: "La description d’une sous-tâche dépasse 2 000 caractères"
        }
    }
}

public enum ExternalTaskInboxError: Error, LocalizedError, Sendable {
    case requestTooLarge

    public var errorDescription: String? {
        switch self {
        case .requestTooLarge: "La requête dépasse la limite locale de 256 Ko"
        }
    }
}

public struct ExternalTaskInbox {
    public let directoryURL: URL
    public let rejectedDirectoryURL: URL

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(directoryURL: URL? = nil) {
        let root = directoryURL
            ?? QuartzPaths.applicationSupportDirectory()
                .appendingPathComponent("Inbox", isDirectory: true)
        self.directoryURL = root
        rejectedDirectoryURL = root.appendingPathComponent("Rejected", isDirectory: true)

        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    @discardableResult
    public func enqueue(_ request: ExternalTaskRequest) throws -> URL {
        _ = try request.makeTask()
        try prepareDirectories()
        let destination = directoryURL.appendingPathComponent("\(request.id.uuidString).json")
        let data = try encoder.encode(request)
        try data.write(to: destination, options: .atomic)
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: destination.path
        )
        return destination
    }

    public func pendingFiles() throws -> [URL] {
        try prepareDirectories()
        return try FileManager.default
            .contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
            .filter { $0.pathExtension.lowercased() == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    public func decode(_ fileURL: URL) throws -> ExternalTaskRequest {
        let values = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        guard values.isRegularFile == true else { throw CocoaError(.fileReadInvalidFileName) }
        guard (values.fileSize ?? 0) <= 256 * 1_024 else {
            throw ExternalTaskInboxError.requestTooLarge
        }
        return try decoder.decode(ExternalTaskRequest.self, from: Data(contentsOf: fileURL))
    }

    public func markProcessed(_ fileURL: URL) throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try FileManager.default.removeItem(at: fileURL)
    }

    public func reject(_ fileURL: URL) throws {
        try prepareDirectories()
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        var destination = rejectedDirectoryURL.appendingPathComponent(fileURL.lastPathComponent)
        if FileManager.default.fileExists(atPath: destination.path) {
            destination = rejectedDirectoryURL.appendingPathComponent(
                "\(UUID().uuidString)-\(fileURL.lastPathComponent)"
            )
        }
        try FileManager.default.moveItem(at: fileURL, to: destination)
    }

    private func prepareDirectories() throws {
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try FileManager.default.createDirectory(
            at: rejectedDirectoryURL,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: directoryURL.path
        )
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: rejectedDirectoryURL.path
        )
    }
}

public struct ExternalPostItRequest: Codable, Equatable, Identifiable, Sendable {
    public static let currentVersion = 1

    public var version: Int
    public var id: UUID
    public var createdAt: Date
    public var source: String?
    public var text: String
    public var scope: PostItScope
    public var date: Date?

    public init(
        version: Int = ExternalPostItRequest.currentVersion,
        id: UUID = UUID(),
        createdAt: Date = Date(),
        source: String? = nil,
        text: String,
        scope: PostItScope = .persistent,
        date: Date? = nil
    ) {
        self.version = version
        self.id = id
        self.createdAt = createdAt
        self.source = source
        self.text = text
        self.scope = scope
        self.date = date
    }

    public func makePostIt(calendar: Calendar = .french) throws -> PostItNote {
        guard version == Self.currentVersion else {
            throw ExternalTaskValidationError.unsupportedVersion(version)
        }
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else { throw ExternalTaskValidationError.emptyTitle }
        guard cleanText.count <= 10_000 else { throw ExternalTaskValidationError.notesTooLong }
        if scope == .daily, date == nil { throw ExternalPostItValidationError.dailyRequiresDate }

        return PostItNote(
            id: id,
            text: cleanText,
            tone: scope == .daily ? .sage : .parchment,
            scope: scope,
            dayKey: date.map { LocalDay.key(for: $0, calendar: calendar) },
            createdAt: createdAt,
            updatedAt: createdAt
        )
    }
}

public enum ExternalPostItValidationError: Error, LocalizedError, Sendable {
    case dailyRequiresDate

    public var errorDescription: String? {
        "Un post-it daily nécessite une date."
    }
}

public struct ExternalPostItInbox {
    public let directoryURL: URL
    public let rejectedDirectoryURL: URL

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(directoryURL: URL? = nil) {
        let root = directoryURL
            ?? QuartzPaths.applicationSupportDirectory()
                .appendingPathComponent("PostItInbox", isDirectory: true)
        self.directoryURL = root
        self.rejectedDirectoryURL = root.appendingPathComponent("Rejected", isDirectory: true)
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    @discardableResult
    public func enqueue(_ request: ExternalPostItRequest) throws -> URL {
        _ = try request.makePostIt()
        try prepareDirectories()
        let destination = directoryURL.appendingPathComponent("\(request.id.uuidString).json")
        let data = try encoder.encode(request)
        try data.write(to: destination, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destination.path)
        return destination
    }

    public func pendingFiles() throws -> [URL] {
        try prepareDirectories()
        return try FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        .filter { $0.pathExtension.lowercased() == "json" }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    public func decode(_ fileURL: URL) throws -> ExternalPostItRequest {
        let values = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        guard values.isRegularFile == true else { throw CocoaError(.fileReadInvalidFileName) }
        guard (values.fileSize ?? 0) <= 256 * 1_024 else { throw ExternalTaskInboxError.requestTooLarge }
        return try decoder.decode(ExternalPostItRequest.self, from: Data(contentsOf: fileURL))
    }

    public func markProcessed(_ fileURL: URL) throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try FileManager.default.removeItem(at: fileURL)
    }

    public func reject(_ fileURL: URL) throws {
        try prepareDirectories()
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        var destination = rejectedDirectoryURL.appendingPathComponent(fileURL.lastPathComponent)
        if FileManager.default.fileExists(atPath: destination.path) {
            destination = rejectedDirectoryURL.appendingPathComponent("\(UUID().uuidString)-\(fileURL.lastPathComponent)")
        }
        try FileManager.default.moveItem(at: fileURL, to: destination)
    }

    private func prepareDirectories() throws {
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try FileManager.default.createDirectory(
            at: rejectedDirectoryURL,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directoryURL.path)
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: rejectedDirectoryURL.path)
    }
}
