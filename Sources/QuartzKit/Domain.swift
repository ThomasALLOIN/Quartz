import Foundation

public enum RecurrenceRule: String, Codable, CaseIterable, Identifiable, Sendable {
    case none
    case daily
    case weekdays
    case weekly
    case monthly

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .none: "Jamais"
        case .daily: "Chaque jour"
        case .weekdays: "Jours ouvrés"
        case .weekly: "Chaque semaine"
        case .monthly: "Chaque mois"
        }
    }

    public var shortLabel: String? {
        switch self {
        case .none: nil
        case .daily: "Tous les jours"
        case .weekdays: "Lun–ven"
        case .weekly: "Chaque semaine"
        case .monthly: "Chaque mois"
        }
    }
}

public enum ReminderOption: String, Codable, CaseIterable, Identifiable, Sendable {
    case none
    case atTime
    case fiveMinutes
    case fifteenMinutes
    case thirtyMinutes
    case oneHour

    public var id: String { rawValue }

    public var minutesBefore: Int? {
        switch self {
        case .none: nil
        case .atTime: 0
        case .fiveMinutes: 5
        case .fifteenMinutes: 15
        case .thirtyMinutes: 30
        case .oneHour: 60
        }
    }

    public var label: String {
        switch self {
        case .none: "Aucun"
        case .atTime: "À l’heure"
        case .fiveMinutes: "5 min avant"
        case .fifteenMinutes: "15 min avant"
        case .thirtyMinutes: "30 min avant"
        case .oneHour: "1 h avant"
        }
    }
}

public struct TodoSubtask: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var description: String?
    public var completedDays: Set<String>

    public init(
        id: UUID = UUID(),
        title: String,
        description: String? = nil,
        completedDays: Set<String> = []
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.completedDays = completedDays
    }

    public func isCompleted(on date: Date, calendar: Calendar = .autoupdatingCurrent) -> Bool {
        completedDays.contains(LocalDay.key(for: date, calendar: calendar))
    }
}

public struct TodoTask: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var startDate: Date
    public var dueMinutes: Int?
    public var recurrence: RecurrenceRule
    public var reminder: ReminderOption
    public var notes: String
    public var subtasks: [TodoSubtask]
    public var completedDays: Set<String>
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        startDate: Date,
        dueMinutes: Int? = nil,
        recurrence: RecurrenceRule = .none,
        reminder: ReminderOption = .none,
        notes: String = "",
        subtasks: [TodoSubtask] = [],
        completedDays: Set<String> = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.dueMinutes = dueMinutes
        self.recurrence = recurrence
        self.reminder = reminder
        self.notes = notes
        self.subtasks = subtasks
        self.completedDays = completedDays
        self.createdAt = createdAt
    }

    public func occurs(on date: Date, calendar: Calendar = .autoupdatingCurrent) -> Bool {
        let day = calendar.startOfDay(for: date)
        let firstDay = calendar.startOfDay(for: startDate)
        guard day >= firstDay else { return false }

        switch recurrence {
        case .none:
            return calendar.isDate(day, inSameDayAs: firstDay)
        case .daily:
            return true
        case .weekdays:
            let weekday = calendar.component(.weekday, from: day)
            return (2...6).contains(weekday)
        case .weekly:
            return calendar.component(.weekday, from: day) == calendar.component(.weekday, from: firstDay)
        case .monthly:
            let desiredDay = calendar.component(.day, from: firstDay)
            let lastDay = calendar.range(of: .day, in: .month, for: day)?.count ?? desiredDay
            return calendar.component(.day, from: day) == min(desiredDay, lastDay)
        }
    }

    public func isCompleted(on date: Date, calendar: Calendar = .autoupdatingCurrent) -> Bool {
        completedDays.contains(LocalDay.key(for: date, calendar: calendar))
    }

    public func progress(on date: Date, calendar: Calendar = .autoupdatingCurrent) -> Double {
        if isCompleted(on: date, calendar: calendar) { return 1 }
        guard !subtasks.isEmpty else { return 0 }
        let completed = subtasks.filter { $0.isCompleted(on: date, calendar: calendar) }.count
        return Double(completed) / Double(subtasks.count)
    }

    public func dueDate(on date: Date, calendar: Calendar = .autoupdatingCurrent) -> Date? {
        guard let dueMinutes else { return nil }
        return calendar.date(
            byAdding: .minute,
            value: dueMinutes,
            to: calendar.startOfDay(for: date)
        )
    }

    /// Vrai uniquement pendant la minute exacte de l’échéance d’une occurrence
    /// non terminée. La date de référence permet de tester ce comportement sans
    /// dépendre de l’horloge réelle.
    public func isDueNow(
        on date: Date,
        at now: Date = Date(),
        calendar: Calendar = .autoupdatingCurrent
    ) -> Bool {
        guard
            occurs(on: date, calendar: calendar),
            !isCompleted(on: date, calendar: calendar),
            calendar.isDate(date, inSameDayAs: now),
            let due = dueDate(on: date, calendar: calendar)
        else { return false }
        return calendar.isDate(due, equalTo: now, toGranularity: .minute)
    }
}

public enum LocalDay {
    public static func key(for date: Date, calendar: Calendar = .autoupdatingCurrent) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    public static func start(of date: Date, calendar: Calendar = .autoupdatingCurrent) -> Date {
        calendar.startOfDay(for: date)
    }

    public static func date(
        from key: String,
        calendar: Calendar = .autoupdatingCurrent
    ) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }
}

public enum TaskMetrics {
    public static func progress(
        for tasks: [TodoTask],
        on date: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> Double {
        let occurrences = tasks.filter { $0.occurs(on: date, calendar: calendar) }
        guard !occurrences.isEmpty else { return 0 }
        return occurrences.reduce(0) { $0 + $1.progress(on: date, calendar: calendar) }
            / Double(occurrences.count)
    }

    public static func completedCount(
        for tasks: [TodoTask],
        on date: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> Int {
        tasks.filter {
            $0.occurs(on: date, calendar: calendar)
                && $0.isCompleted(on: date, calendar: calendar)
        }.count
    }

    public static func occurrenceDates(
        for task: TodoTask,
        from start: Date,
        through end: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> [Date] {
        var result: [Date] = []
        var cursor = calendar.startOfDay(for: start)
        let last = calendar.startOfDay(for: end)

        while cursor <= last {
            if task.occurs(on: cursor, calendar: calendar) {
                result.append(cursor)
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return result
    }
}

public extension Calendar {
    static var french: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "fr_FR")
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        calendar.timeZone = .autoupdatingCurrent
        return calendar
    }
}
