import Foundation

public enum FrenchReminderHint: Equatable, Sendable {
    case absent
    case supported(ReminderOption)
    case unsupported
}

/// Indices français à forte confiance extraits avant de présenter la proposition
/// du petit LLM. Ils ne corrigent que les informations écrites explicitement.
public struct FrenchTaskHints: Equatable, Sendable {
    public let recurrence: RecurrenceRule?
    public let dueMinutes: Int?
    public let startDate: Date?
    public let hasExplicitDate: Bool
    public let reminder: FrenchReminderHint
    public let containsMultipleTasks: Bool

    public init(
        recurrence: RecurrenceRule?,
        dueMinutes: Int?,
        startDate: Date?,
        hasExplicitDate: Bool,
        reminder: FrenchReminderHint,
        containsMultipleTasks: Bool
    ) {
        self.recurrence = recurrence
        self.dueMinutes = dueMinutes
        self.startDate = startDate
        self.hasExplicitDate = hasExplicitDate
        self.reminder = reminder
        self.containsMultipleTasks = containsMultipleTasks
    }

    public static func extract(
        from text: String,
        referenceDate: Date = Date(),
        calendar: Calendar = .french
    ) -> FrenchTaskHints {
        let value = normalized(text)
        let dueMinutes = time(in: value)
        let dateHint = date(in: value, referenceDate: referenceDate, calendar: calendar)
        return FrenchTaskHints(
            recurrence: recurrence(in: value),
            dueMinutes: dueMinutes,
            startDate: dateHint.date,
            hasExplicitDate: dateHint.detected,
            reminder: reminder(in: value, dueMinutes: dueMinutes),
            containsMultipleTasks: multipleTasks(in: value, originalText: text)
        )
    }

    public func cleanedTitle(_ title: String) -> String {
        let hasReminder: Bool
        switch reminder {
        case .absent: hasReminder = false
        case .supported, .unsupported: hasReminder = true
        }
        guard recurrence != nil || dueMinutes != nil || hasExplicitDate || hasReminder else {
            return title.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var value = title
        let directives = [
            #"\b(?:chaque|tous?\s+les?|tout\s+les?)\s+jours?\s+ouvr[eé]s?\b"#,
            #"\bdu\s+lundi\s+au\s+vendredi\b"#,
            #"\b(?:chaque|tous?\s+les?|tout\s+les?)\s+jours?\b"#,
            #"\bquotidien(?:ne|nement|nes|s)?\b"#,
            #"\b(?:chaque|toutes?\s+les|tous?\s+les|une\s+fois\s+par)\s+semaines?\b"#,
            #"\bhebdomadaire(?:ment)?\b"#,
            #"\b(?:chaque|tous?\s+les|une\s+fois\s+par)\s+mois\b"#,
            #"\bmensuel(?:le|lement|les|s)?\b"#,
            #"\b(?:chaque|tous?\s+les)\s+(?:lundis?|mardis?|mercredis?|jeudis?|vendredis?|samedis?|dimanches?)\b"#,
            #"\bapr[eè]s[- ]demain\b"#,
            #"\b(?:aujourd['’]hui|demain|dem1)\b"#,
            #"\b(?:ce\s+soir|ce\s+matin|cet\s+apr[eè]s-midi)\b"#,
            #"\bdans\s+(?:\d{1,4}|un|une|deux|trois|quatre|cinq|six|sept|huit|neuf|dix)\s+jours?\b"#,
            #"\bdans\s+(?:\d{1,3}|un|une|deux|trois|quatre|cinq|six|sept|huit|neuf|dix)\s+(?:semaines?|mois)\b"#,
            #"\b(?:la\s+semaine|le\s+mois)\s+prochaine?\b"#,
            #"\b(?:le\s+)?(?:[0-3]?\d)[/.](?:[01]?\d)[/.](?:\d{4})\b"#,
            #"\b(?:le\s+)?(?:[0-3]?\d)\s+(?:janvier|f[eé]vrier|mars|avril|mai|juin|juillet|ao[uû]t|septembre|octobre|novembre|d[eé]cembre)(?:\s+\d{4})?\b"#,
            #"\b(?:ce\s+)?(?:lundi|mardi|mercredi|jeudi|vendredi|samedi|dimanche)(?:\s+prochain)?\b"#,
            #"\b(?:avec\s+un\s+)?rappel\s*(?:de\s+)?(?:\d{1,3}\s*(?:minutes?|mins?|h|heures?)|un\s+quart\s+d['’]heure|une\s+demi[- ]heure|une\s+heure)?\s*(?:avant|[aà]\s+l['’]heure)?\b"#,
            #"\b(?:rappelle|pr[eé]viens|notifie)[- ]?moi\s*(?:de\s+)?(?:\d{1,3}\s*(?:minutes?|mins?|h|heures?)|un\s+quart\s+d['’]heure|une\s+demi[- ]heure|une\s+heure)?\s*(?:avant|[aà]\s+l['’]heure)?\b"#,
            #"\b(?:me\s+)?pr[eé]venir\s*(?:de\s+)?(?:\d{1,3}\s*(?:minutes?|mins?|h|heures?)|un\s+quart\s+d['’]heure|une\s+demi[- ]heure|une\s+heure)?\s*(?:avant|[aà]\s+l['’]heure)?\b"#,
            #"\s*(?:\b(?:à|a|vers|pour)\s+)?(?:[01]?\d|2[0-3])\s*(?:h|heures?|:)\s*(?:[0-5]?\d)?\b"#,
        ]

        for pattern in directives {
            value = replacing(pattern, in: value, with: " ")
        }

        value = replacing(
            #"^\s*(?:ajoute(?:r)?|cr[eé]e(?:r)?|mets?|note)\s+(?:une\s+t[aâ]che\s+)?(?:de\s+)?"#,
            in: value,
            with: ""
        )
        if hasReminder {
            value = replacing(#"^\s*d['’]?(?:e\s+)?"#, in: value, with: "")
        }
        value = replacing(#"\s+"#, in: value, with: " ")
        value = value.trimmingCharacters(
            in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ",.;:–—-"))
        )

        guard !value.isEmpty else {
            return title.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return value.prefix(1).uppercased() + String(value.dropFirst())
    }

    private static func recurrence(in value: String) -> RecurrenceRule? {
        if contains(
            #"\b(?:chaque|tous?\s+les?|tout\s+les?)\s+jours?\s+ouvres?\b"#,
            in: value
        ) || contains(#"\bdu\s+lundi\s+au\s+vendredi\b"#, in: value) {
            return .weekdays
        }
        if contains(#"\b(?:chaque|tous?\s+les?|tout\s+les?)\s+jours?\b"#, in: value)
            || contains(#"\bquotidien(?:ne|nement|nes|s)?\b"#, in: value)
        {
            return .daily
        }
        if contains(
            #"\b(?:chaque|toutes?\s+les|tous?\s+les|une\s+fois\s+par)\s+semaines?\b"#,
            in: value
        ) || contains(#"\bhebdomadaire(?:ment)?\b"#, in: value)
            || contains(
                #"\b(?:chaque|tous?\s+les)\s+(?:lundis?|mardis?|mercredis?|jeudis?|vendredis?|samedis?|dimanches?)\b"#,
                in: value
            )
        {
            return .weekly
        }
        if contains(#"\b(?:chaque|tous?\s+les|une\s+fois\s+par)\s+mois\b"#, in: value)
            || contains(#"\bmensuel(?:le|lement|les|s)?\b"#, in: value)
        {
            return .monthly
        }
        return nil
    }

    private static func time(in value: String) -> Int? {
        let pattern = #"(?<!\d)([01]?\d|2[0-3])\s*(?:h|heures?|:)\s*([0-5]?\d)?(?!\d)(?!\s*(?:avant|plus\s+tot))"#
        guard let match = firstMatch(pattern, in: value),
              let hour = integer(at: 1, in: match, text: value)
        else { return nil }
        return hour * 60 + (integer(at: 2, in: match, text: value) ?? 0)
    }

    private static func date(
        in value: String,
        referenceDate: Date,
        calendar: Calendar
    ) -> (date: Date?, detected: Bool) {
        let reference = calendar.startOfDay(for: referenceDate)

        if contains(#"\bapres[- ]demain\b"#, in: value) {
            return (calendar.date(byAdding: .day, value: 2, to: reference), true)
        }
        if contains(#"\baujourd'hui\b"#, in: value) {
            return (reference, true)
        }
        if contains(#"\b(?:ce\s+soir|ce\s+matin|cet\s+apres-midi)\b"#, in: value) {
            return (reference, true)
        }
        if contains(#"\b(?:demain|dem1)\b"#, in: value) {
            return (calendar.date(byAdding: .day, value: 1, to: reference), true)
        }

        let numberWords = [
            "un": 1, "une": 1, "deux": 2, "trois": 3, "quatre": 4, "cinq": 5,
            "six": 6, "sept": 7, "huit": 8, "neuf": 9, "dix": 10,
        ]
        if let match = firstMatch(
            #"\bdans\s+(\d{1,5}|un|une|deux|trois|quatre|cinq|six|sept|huit|neuf|dix)\s+jours?\b"#,
            in: value
        ), let token = string(at: 1, in: match, text: value) {
            let days = Int(token) ?? numberWords[token]
            guard let days, (0...3_650).contains(days) else { return (nil, true) }
            return (calendar.date(byAdding: .day, value: days, to: reference), true)
        }
        if let match = firstMatch(
            #"\bdans\s+(\d{1,3}|un|une|deux|trois|quatre|cinq|six|sept|huit|neuf|dix)\s+(semaines?|mois)\b"#,
            in: value
        ), let token = string(at: 1, in: match, text: value),
           let unit = string(at: 2, in: match, text: value)
        {
            let amount = Int(token) ?? numberWords[token]
            guard let amount, (0...520).contains(amount) else { return (nil, true) }
            let component: Calendar.Component = unit.hasPrefix("semaine") ? .weekOfYear : .month
            return (calendar.date(byAdding: component, value: amount, to: reference), true)
        }
        if contains(#"\bla\s+semaine\s+prochaine\b"#, in: value) {
            return (calendar.date(byAdding: .weekOfYear, value: 1, to: reference), true)
        }
        if contains(#"\ble\s+mois\s+prochain\b"#, in: value) {
            return (calendar.date(byAdding: .month, value: 1, to: reference), true)
        }

        if let match = firstMatch(#"\b(\d{4})-(\d{1,2})-(\d{1,2})\b"#, in: value) {
            return (
                validDate(
                    year: integer(at: 1, in: match, text: value),
                    month: integer(at: 2, in: match, text: value),
                    day: integer(at: 3, in: match, text: value),
                    calendar: calendar
                ),
                true
            )
        }
        if let match = firstMatch(#"\b(\d{1,2})[/.](\d{1,2})[/.](\d{4})\b"#, in: value) {
            return (
                validDate(
                    year: integer(at: 3, in: match, text: value),
                    month: integer(at: 2, in: match, text: value),
                    day: integer(at: 1, in: match, text: value),
                    calendar: calendar
                ),
                true
            )
        }

        let months = [
            "janvier": 1, "fevrier": 2, "mars": 3, "avril": 4, "mai": 5, "juin": 6,
            "juillet": 7, "aout": 8, "septembre": 9, "octobre": 10,
            "novembre": 11, "decembre": 12,
        ]
        if let match = firstMatch(
            #"\b(?:le\s+)?(\d{1,2})\s+(janvier|fevrier|mars|avril|mai|juin|juillet|aout|septembre|octobre|novembre|decembre)(?:\s+(\d{4}))?\b"#,
            in: value
        ), let day = integer(at: 1, in: match, text: value),
           let monthName = string(at: 2, in: match, text: value),
           let month = months[monthName]
        {
            if let year = integer(at: 3, in: match, text: value) {
                return (validDate(year: year, month: month, day: day, calendar: calendar), true)
            }
            var year = calendar.component(.year, from: reference)
            guard var resolved = validDate(year: year, month: month, day: day, calendar: calendar) else {
                return (nil, true)
            }
            if resolved < reference {
                year += 1
                guard let next = validDate(year: year, month: month, day: day, calendar: calendar) else {
                    return (nil, true)
                }
                resolved = next
            }
            return (resolved, true)
        }

        guard !contains(#"\bdu\s+lundi\s+au\s+vendredi\b"#, in: value) else {
            return (nil, false)
        }
        let weekdays = [
            "dimanche": 1, "lundi": 2, "mardi": 3, "mercredi": 4,
            "jeudi": 5, "vendredi": 6, "samedi": 7,
        ]
        if let match = firstMatch(
            #"\b(?:ce\s+|chaque\s+|tous?\s+les\s+)?(lundi|mardi|mercredi|jeudi|vendredi|samedi|dimanche)s?(?:\s+prochain)?\b"#,
            in: value
        ), let weekdayName = string(at: 1, in: match, text: value),
           let desiredWeekday = weekdays[weekdayName]
        {
            let currentWeekday = calendar.component(.weekday, from: reference)
            var offset = (desiredWeekday - currentWeekday + 7) % 7
            let wholeMatch = string(at: 0, in: match, text: value) ?? ""
            if offset == 0, wholeMatch.contains("prochain") { offset = 7 }
            return (calendar.date(byAdding: .day, value: offset, to: reference), true)
        }

        return (nil, false)
    }

    private static func reminder(in value: String, dueMinutes: Int?) -> FrenchReminderHint {
        let hasIntent = contains(
            #"\b(?:rappel|rappelle|previens|notifie)(?:[- ]?moi)?\b|\b(?:me\s+)?prevenir\b"#,
            in: value
        )
        guard hasIntent else { return .absent }

        if contains(#"\bun\s+quart\s+d'heure\s+avant\b"#, in: value) {
            return .supported(.fifteenMinutes)
        }
        if contains(#"\bune\s+demi[- ]heure\s+avant\b"#, in: value) {
            return .supported(.thirtyMinutes)
        }
        if contains(#"\bune\s+heure\s+avant\b"#, in: value) {
            return .supported(.oneHour)
        }
        if let match = firstMatch(#"\b(cinq|quinze|trente)\s+minutes?\s+avant\b"#, in: value),
           let amount = string(at: 1, in: match, text: value)
        {
            return switch amount {
            case "cinq": .supported(.fiveMinutes)
            case "quinze": .supported(.fifteenMinutes)
            case "trente": .supported(.thirtyMinutes)
            default: .unsupported
            }
        }
        if let match = firstMatch(#"\b(\d{1,3})\s*(minutes?|mins?|h|heures?)\s+avant\b"#, in: value),
           let amount = integer(at: 1, in: match, text: value),
           let unit = string(at: 2, in: match, text: value)
        {
            let minutes = unit.hasPrefix("h") ? amount * 60 : amount
            return switch minutes {
            case 5: .supported(.fiveMinutes)
            case 15: .supported(.fifteenMinutes)
            case 30: .supported(.thirtyMinutes)
            case 60: .supported(.oneHour)
            default: .unsupported
            }
        }
        return .supported(.atTime)
    }

    private static func multipleTasks(in value: String, originalText: String) -> Bool {
        if contains(#"\b(?:deux|trois|plusieurs)\s+taches?\b"#, in: value) {
            return true
        }

        let hasSubtaskContext = contains(
            #"\b(?:sous[- ]?taches?|etapes?|check[- ]?list)\b"#,
            in: value
        )
        guard !hasSubtaskContext else { return false }

        let listLines = originalText
            .split(whereSeparator: \Character.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter {
                contains(#"^(?:[-*•]|\d+[.)])\s+\S+"#, in: $0)
            }
        if listLines.count >= 2 { return true }

        let actionVerb = #"\b[a-z][a-z'’-]{1,}(?:er|ir|re)\b"#
        let clauses = value.split(separator: ";").map(String.init)
        if clauses.count >= 2, clauses.filter({ contains(actionVerb, in: $0) }).count >= 2 {
            return true
        }

        guard let connector = firstMatch(
            #"\b(?:et|puis|ensuite)\s+(?:(?:je|tu|il|elle|on|nous|vous|ils|elles|lui|leur|me|te|se|de)\s+){0,3}([a-z][a-z'-]{1,}(?:er|ir|re))\b"#,
            in: value
        ) else { return false }
        let prefixRange = NSRange(location: 0, length: connector.range.location)
        guard let prefix = Range(prefixRange, in: value) else { return false }
        return contains(actionVerb, in: String(value[prefix]))
    }

    private static func validDate(
        year: Int?,
        month: Int?,
        day: Int?,
        calendar: Calendar
    ) -> Date? {
        guard let year, let month, let day,
              let result = calendar.date(from: DateComponents(year: year, month: month, day: day))
        else { return nil }
        let verified = calendar.dateComponents([.year, .month, .day], from: result)
        guard verified.year == year, verified.month == month, verified.day == day else { return nil }
        return calendar.startOfDay(for: result)
    }

    private static func normalized(_ text: String) -> String {
        text
            .replacingOccurrences(of: "’", with: "'")
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: Locale(identifier: "fr_FR")
            )
    }

    private static func firstMatch(_ pattern: String, in text: String) -> NSTextCheckingResult? {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return expression.firstMatch(in: text, range: range)
    }

    private static func contains(_ pattern: String, in text: String) -> Bool {
        firstMatch(pattern, in: text) != nil
    }

    private static func string(
        at index: Int,
        in match: NSTextCheckingResult,
        text: String
    ) -> String? {
        guard index < match.numberOfRanges,
              match.range(at: index).location != NSNotFound,
              let range = Range(match.range(at: index), in: text)
        else { return nil }
        return String(text[range])
    }

    private static func integer(
        at index: Int,
        in match: NSTextCheckingResult,
        text: String
    ) -> Int? {
        string(at: index, in: match, text: text).flatMap(Int.init)
    }

    private func replacing(_ pattern: String, in text: String, with replacement: String) -> String {
        guard let expression = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive]
        ) else { return text }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return expression.stringByReplacingMatches(
            in: text,
            range: range,
            withTemplate: replacement
        )
    }
}
