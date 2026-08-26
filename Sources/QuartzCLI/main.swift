import Darwin
import QuartzKit
import Foundation

private struct CLIInput: Decodable {
    var title: String?
    var date: String?
    var time: String?
    var recurrence: String?
    var reminder: String?
    var notes: String?
    var subtasks: [CLISubtask]?
    var source: String?
    var id: UUID?
}

private struct CLISubtask: Decodable {
    var title: String
    var description: String?
}

private struct CLIResponse: Encodable {
    let ok = true
    let queued = true
    let requestID: String
    let inbox: String
}

private enum CLIError: Error, LocalizedError {
    case missingCommand
    case unsupportedCommand(String)
    case missingTitle
    case missingValue(String)
    case unknownOption(String)
    case invalidDate(String)
    case invalidTime(String)
    case invalidRecurrence(String)
    case invalidReminder(String)
    case emptyJSON

    var errorDescription: String? {
        switch self {
        case .missingCommand: "Commande manquante. Utilisez « quartz ajouter --help »"
        case let .unsupportedCommand(command): "Commande inconnue : \(command)"
        case .missingTitle: "Le titre est obligatoire (--titre)"
        case let .missingValue(option): "Valeur manquante après \(option)"
        case let .unknownOption(option): "Option inconnue : \(option)"
        case let .invalidDate(value): "Date invalide : \(value). Utilisez aujourd’hui, demain ou AAAA-MM-JJ"
        case let .invalidTime(value): "Heure invalide : \(value). Utilisez HH:mm"
        case let .invalidRecurrence(value): "Récurrence invalide : \(value)"
        case let .invalidReminder(value): "Rappel invalide : \(value)"
        case .emptyJSON: "Aucun JSON reçu sur l’entrée standard"
        }
    }
}

private let help = """
Usage :
  quartz ajouter --titre "Titre" [options]
  quartz add "Titre" [options]
  quartz ajouter --json < demande.json

Options :
  --titre, --title TEXT             Titre obligatoire
  --date DATE                       aujourd’hui, demain ou AAAA-MM-JJ
  --heure, --time HH:mm             Heure d’échéance
  --recurrence VALEUR               jamais, quotidien, ouvres, hebdomadaire, mensuel
  --rappel, --reminder VALEUR       aucun, heure, 5m, 15m, 30m, 1h
  --notes TEXT                      Notes de la tâche
  --sous-tache, --subtask TEXT      Répétable ; « titre :: description » accepté
  --source TEXT                     Nom de l’agent (chatgpt, claude, hermes, opencode…)
  --id UUID                         Identifiant stable facultatif pour les reprises sans doublon
  --json                            Lit un objet JSON sur l’entrée standard

Exemple :
  quartz ajouter --titre "Préparer le dossier" --date demain --heure 09:30 \\
    --rappel 15m --sous-tache "Relire les notes" --source claude
"""

private func value(after option: String, arguments: [String], index: inout Int) throws -> String {
    index += 1
    guard index < arguments.count else { throw CLIError.missingValue(option) }
    return arguments[index]
}

private func parseArguments(_ arguments: [String]) throws -> CLIInput {
    var input = CLIInput()
    var subtasks: [CLISubtask] = []
    var index = 1

    if index < arguments.count, !arguments[index].hasPrefix("-") {
        input.title = arguments[index]
        index += 1
    }

    while index < arguments.count {
        let option = arguments[index]
        switch option {
        case "--titre", "--title":
            input.title = try value(after: option, arguments: arguments, index: &index)
        case "--date":
            input.date = try value(after: option, arguments: arguments, index: &index)
        case "--heure", "--time":
            input.time = try value(after: option, arguments: arguments, index: &index)
        case "--recurrence":
            input.recurrence = try value(after: option, arguments: arguments, index: &index)
        case "--rappel", "--reminder":
            input.reminder = try value(after: option, arguments: arguments, index: &index)
        case "--notes":
            input.notes = try value(after: option, arguments: arguments, index: &index)
        case "--source":
            input.source = try value(after: option, arguments: arguments, index: &index)
        case "--id":
            let rawID = try value(after: option, arguments: arguments, index: &index)
            guard let id = UUID(uuidString: rawID) else { throw CLIError.unknownOption("UUID invalide : \(rawID)") }
            input.id = id
        case "--sous-tache", "--subtask":
            let raw = try value(after: option, arguments: arguments, index: &index)
            let parts = raw.components(separatedBy: "::")
            let title = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let description = parts.dropFirst().joined(separator: "::")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            subtasks.append(CLISubtask(title: title, description: description.isEmpty ? nil : description))
        case "--help", "-h":
            print(help)
            exit(EXIT_SUCCESS)
        case "--json":
            throw CLIError.unknownOption("--json doit être utilisé seul après ajouter")
        default:
            throw CLIError.unknownOption(option)
        }
        index += 1
    }
    input.subtasks = subtasks
    return input
}

private func parseDate(_ rawValue: String?) throws -> Date {
    let calendar = Calendar.french
    let today = calendar.startOfDay(for: Date())
    guard let rawValue else { return today }
    let value = rawValue.lowercased()
        .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))

    if ["aujourd'hui", "aujourd’hui", "today"].contains(value) { return today }
    if ["demain", "tomorrow"].contains(value) {
        return calendar.date(byAdding: .day, value: 1, to: today)!
    }

    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = calendar.timeZone
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.isLenient = false
    guard rawValue.count == 10, let date = formatter.date(from: rawValue) else {
        throw CLIError.invalidDate(rawValue)
    }
    return calendar.startOfDay(for: date)
}

private func parseTime(_ rawValue: String?) throws -> Int? {
    guard let rawValue else { return nil }
    let parts = rawValue.split(separator: ":", omittingEmptySubsequences: false)
    guard
        parts.count == 2,
        parts[0].count == 2,
        parts[1].count == 2,
        let hour = Int(parts[0]),
        let minute = Int(parts[1]),
        (0..<24).contains(hour),
        (0..<60).contains(minute)
    else { throw CLIError.invalidTime(rawValue) }
    return hour * 60 + minute
}

private func parseRecurrence(_ rawValue: String?) throws -> RecurrenceRule {
    guard let rawValue else { return .none }
    let value = rawValue.lowercased()
        .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
    return switch value {
    case "none", "jamais", "aucune": .none
    case "daily", "quotidien", "quotidienne", "chaque-jour": .daily
    case "weekdays", "ouvres", "jours-ouvres", "lun-ven": .weekdays
    case "weekly", "hebdomadaire": .weekly
    case "monthly", "mensuel", "mensuelle": .monthly
    default: throw CLIError.invalidRecurrence(rawValue)
    }
}

private func parseReminder(_ rawValue: String?) throws -> ReminderOption {
    guard let rawValue else { return .none }
    let value = rawValue.lowercased()
        .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
    return switch value {
    case "none", "aucun", "jamais": .none
    case "at-time", "heure", "0", "0m": .atTime
    case "5m", "5min": .fiveMinutes
    case "15m", "15min": .fifteenMinutes
    case "30m", "30min": .thirtyMinutes
    case "1h", "60m", "60min": .oneHour
    default: throw CLIError.invalidReminder(rawValue)
    }
}

private func makeRequest(from input: CLIInput) throws -> ExternalTaskRequest {
    guard let title = input.title else { throw CLIError.missingTitle }
    let request = ExternalTaskRequest(
        id: input.id ?? UUID(),
        source: input.source,
        title: title,
        startDate: try parseDate(input.date),
        dueMinutes: try parseTime(input.time),
        recurrence: try parseRecurrence(input.recurrence),
        reminder: try parseReminder(input.reminder),
        notes: input.notes ?? "",
        subtasks: (input.subtasks ?? []).map {
            ExternalSubtaskDraft(title: $0.title, description: $0.description)
        }
    )
    _ = try request.makeTask()
    return request
}

do {
    let arguments = Array(CommandLine.arguments.dropFirst())
    guard let command = arguments.first else { throw CLIError.missingCommand }
    if ["--help", "-h", "help", "aide"].contains(command) {
        print(help)
        exit(EXIT_SUCCESS)
    }
    guard ["ajouter", "add"].contains(command.lowercased()) else {
        throw CLIError.unsupportedCommand(command)
    }

    let input: CLIInput
    if arguments.dropFirst().contains("--json") {
        guard arguments.count == 2, arguments[1] == "--json" else {
            throw CLIError.unknownOption("--json doit être utilisé seul après ajouter")
        }
        let data = FileHandle.standardInput.readDataToEndOfFile()
        guard !data.isEmpty else { throw CLIError.emptyJSON }
        input = try JSONDecoder().decode(CLIInput.self, from: data)
    } else {
        input = try parseArguments(arguments)
    }

    let request = try makeRequest(from: input)
    let inbox = ExternalTaskInbox()
    let destination = try inbox.enqueue(request)
    let response = CLIResponse(
        requestID: request.id.uuidString,
        inbox: destination.path
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    print(String(decoding: try encoder.encode(response), as: UTF8.self))
} catch {
    fputs("Erreur Quartz : \(error.localizedDescription)\n", stderr)
    exit(EXIT_FAILURE)
}
