import Foundation

public enum PostItTone: String, Codable, CaseIterable, Sendable {
    case parchment
    case rose
    case sage
    case lavender
}

public enum PostItScope: String, Codable, CaseIterable, Sendable {
    case persistent
    case daily
}

public enum PostItMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case off
    case persistent
    case daily

    public var id: String { rawValue }

    public var next: PostItMode {
        switch self {
        case .off: .persistent
        case .persistent: .daily
        case .daily: .off
        }
    }
}

public struct PostItNote: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var text: String
    public var tone: PostItTone
    public var scope: PostItScope
    public var dayKey: String?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        text: String,
        tone: PostItTone = .parchment,
        scope: PostItScope = .persistent,
        dayKey: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.text = text
        self.tone = tone
        self.scope = scope
        self.dayKey = dayKey
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public func isVisible(on date: Date, calendar: Calendar = .autoupdatingCurrent) -> Bool {
        switch scope {
        case .persistent:
            true
        case .daily:
            dayKey == LocalDay.key(for: date, calendar: calendar)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case text
        case tone
        case scope
        case dayKey
        case createdAt
        case updatedAt
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        text = try values.decode(String.self, forKey: .text)
        tone = try values.decodeIfPresent(PostItTone.self, forKey: .tone) ?? .parchment
        scope = try values.decodeIfPresent(PostItScope.self, forKey: .scope) ?? .persistent
        dayKey = try values.decodeIfPresent(String.self, forKey: .dayKey)
        createdAt = try values.decode(Date.self, forKey: .createdAt)
        updatedAt = try values.decode(Date.self, forKey: .updatedAt)
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encode(text, forKey: .text)
        try values.encode(tone, forKey: .tone)
        try values.encode(scope, forKey: .scope)
        try values.encodeIfPresent(dayKey, forKey: .dayKey)
        try values.encode(createdAt, forKey: .createdAt)
        try values.encode(updatedAt, forKey: .updatedAt)
    }
}
