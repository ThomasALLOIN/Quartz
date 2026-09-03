import Foundation
import QuartzKit

private let supportedProtocolVersions = ["2025-06-18", "2024-11-05"]

private enum MCPServerError: LocalizedError {
    case invalidArguments(String)
    case unknownTool(String)

    var errorDescription: String? {
        switch self {
        case let .invalidArguments(message): message
        case let .unknownTool(name): "Outil MCP inconnu : \(name)"
        }
    }
}

private func json(_ object: Any) {
    guard JSONSerialization.isValidJSONObject(object),
          let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
          let line = String(data: data, encoding: .utf8)
    else { return }
    print(line)
    fflush(stdout)
}

private func response(id: Any, result: [String: Any]) {
    json(["jsonrpc": "2.0", "id": id, "result": result])
}

private func protocolError(id: Any?, code: Int, message: String) {
    var payload: [String: Any] = [
        "jsonrpc": "2.0",
        "error": ["code": code, "message": message]
    ]
    if let id { payload["id"] = id } else { payload["id"] = NSNull() }
    json(payload)
}

private func textResult(_ text: String, isError: Bool = false) -> [String: Any] {
    [
        "content": [["type": "text", "text": text]],
        "isError": isError
    ]
}

private func argumentString(_ arguments: [String: Any], _ key: String) -> String? {
    (arguments[key] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
}

private func requiredString(_ arguments: [String: Any], _ key: String, label: String) throws -> String {
    guard let value = argumentString(arguments, key), !value.isEmpty else {
        throw MCPServerError.invalidArguments("\(label) est obligatoire.")
    }
    return value
}

private func parseDate(_ value: String?) throws -> Date {
    let calendar = Calendar.french
    let today = calendar.startOfDay(for: Date())
    guard let value, !value.isEmpty else { return today }
    let normalized = value.lowercased().folding(
        options: [.diacriticInsensitive, .caseInsensitive],
        locale: Locale(identifier: "fr_FR")
    )
    if ["aujourd'hui", "aujourd’hui", "today"].contains(normalized) { return today }
    if ["demain", "tomorrow"].contains(normalized) {
        return calendar.date(byAdding: .day, value: 1, to: today)!
    }
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = calendar.timeZone
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.isLenient = false
    guard value.count == 10, let date = formatter.date(from: value) else {
        throw MCPServerError.invalidArguments("La date doit être aujourd’hui, demain ou AAAA-MM-JJ.")
    }
    return calendar.startOfDay(for: date)
}

private func parseTime(_ value: String?) throws -> Int? {
    guard let value, !value.isEmpty else { return nil }
    let parts = value.split(separator: ":", omittingEmptySubsequences: false)
    guard parts.count == 2, parts[0].count == 2, parts[1].count == 2,
          let hour = Int(parts[0]), let minute = Int(parts[1]),
          (0..<24).contains(hour), (0..<60).contains(minute)
    else { throw MCPServerError.invalidArguments("L’heure doit être au format HH:mm.") }
    return hour * 60 + minute
}

private func parseRecurrence(_ value: String?) throws -> RecurrenceRule {
    switch value?.lowercased() ?? "none" {
    case "none": .none
    case "daily": .daily
    case "weekdays": .weekdays
    case "weekly": .weekly
    case "monthly": .monthly
    default: throw MCPServerError.invalidArguments("Récurrence invalide.")
    }
}

private func parseReminder(_ value: String?) throws -> ReminderOption {
    switch value?.lowercased() ?? "none" {
    case "none": .none
    case "at-time": .atTime
    case "5m": .fiveMinutes
    case "15m": .fifteenMinutes
    case "30m": .thirtyMinutes
    case "1h": .oneHour
    default: throw MCPServerError.invalidArguments("Rappel invalide.")
    }
}

private func taskTool() -> [String: Any] {
    [
        "name": "quartz_create_task",
        "title": "Créer une tâche Quartz",
        "description": "Ajoute une tâche au calendrier Quartz local. Elle est déposée de manière atomique puis importée par Quartz, même si l’application est fermée.",
        "inputSchema": [
            "type": "object",
            "additionalProperties": false,
            "required": ["title"],
            "properties": [
                "title": ["type": "string", "minLength": 1, "maxLength": 240],
                "date": ["type": "string", "description": "aujourd’hui, demain ou AAAA-MM-JJ"],
                "time": ["type": "string", "pattern": "^(?:[01][0-9]|2[0-3]):[0-5][0-9]$"],
                "recurrence": ["type": "string", "enum": ["none", "daily", "weekdays", "weekly", "monthly"]],
                "reminder": ["type": "string", "enum": ["none", "at-time", "5m", "15m", "30m", "1h"]],
                "notes": ["type": "string", "maxLength": 10000],
                "subtasks": ["type": "array", "maxItems": 100, "items": ["type": "object", "required": ["title"], "properties": ["title": ["type": "string"], "description": ["type": "string"]]]]
            ]
        ],
        "annotations": ["destructiveHint": false, "idempotentHint": false, "openWorldHint": false]
    ]
}

private func postItTool() -> [String: Any] {
    [
        "name": "quartz_create_note",
        "title": "Créer un post-it Quartz",
        "description": "Ajoute un post-it Quartz local : « persistent » reste visible tous les jours ; « daily » est lié à une date.",
        "inputSchema": [
            "type": "object",
            "additionalProperties": false,
            "required": ["text"],
            "properties": [
                "text": ["type": "string", "minLength": 1, "maxLength": 10000],
                "scope": ["type": "string", "enum": ["persistent", "daily"]],
                "date": ["type": "string", "description": "Requis pour une note daily : aujourd’hui, demain ou AAAA-MM-JJ"]
            ]
        ],
        "annotations": ["destructiveHint": false, "idempotentHint": false, "openWorldHint": false]
    ]
}

private func createTask(arguments: [String: Any]) throws -> String {
    let title = try requiredString(arguments, "title", label: "Le titre")
    let date = try parseDate(argumentString(arguments, "date"))
    let time = try parseTime(argumentString(arguments, "time"))
    let recurrence = try parseRecurrence(argumentString(arguments, "recurrence"))
    let reminder = try parseReminder(argumentString(arguments, "reminder"))
    let subtasks = try (arguments["subtasks"] as? [[String: Any]] ?? []).map { item in
        ExternalSubtaskDraft(
            title: try requiredString(item, "title", label: "Le titre d’une sous-tâche"),
            description: argumentString(item, "description")
        )
    }
    let request = ExternalTaskRequest(
        source: "mcp",
        destination: .task,
        title: title,
        startDate: date,
        dueMinutes: time,
        recurrence: recurrence,
        reminder: reminder,
        notes: argumentString(arguments, "notes") ?? "",
        subtasks: subtasks
    )
    let destination = try ExternalTaskInbox().enqueue(request)
    return "Tâche mise en attente pour Quartz (\(request.id.uuidString)). Boîte locale : \(destination.path)"
}

private func createPostIt(arguments: [String: Any]) throws -> String {
    let scope = PostItScope(rawValue: argumentString(arguments, "scope") ?? "persistent")
    guard let scope else { throw MCPServerError.invalidArguments("Le type de note doit être persistent ou daily.") }
    let request = ExternalPostItRequest(
        source: "mcp",
        text: try requiredString(arguments, "text", label: "Le texte"),
        scope: scope,
        date: try argumentString(arguments, "date").map(parseDate)
    )
    let destination = try ExternalPostItInbox().enqueue(request)
    return "Post-it mis en attente pour Quartz (\(request.id.uuidString)). Boîte locale : \(destination.path)"
}

while let line = readLine() {
    guard let data = line.data(using: .utf8) else { continue }
    guard let request = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let method = request["method"] as? String
    else {
        protocolError(id: nil, code: -32700, message: "Requête JSON-RPC invalide")
        continue
    }

    let id = request["id"]
    switch method {
    case "initialize":
        guard let id else { continue }
        let requestedVersion = (request["params"] as? [String: Any])?["protocolVersion"] as? String
        let version = supportedProtocolVersions.contains(requestedVersion ?? "")
            ? requestedVersion!
            : supportedProtocolVersions[0]
        response(id: id, result: [
            "protocolVersion": version,
            "capabilities": ["tools": [:]],
            "serverInfo": ["name": "quartz", "title": "Quartz", "version": "1.0.0"],
            "instructions": "Utilisez les outils Quartz pour créer des tâches et des post-it locaux. Confirmez avec l’utilisateur toute date ou tout contenu ambigu avant l’ajout."
        ])
    case "notifications/initialized":
        continue
    case "ping":
        if let id { response(id: id, result: [:]) }
    case "tools/list":
        if let id { response(id: id, result: ["tools": [taskTool(), postItTool()]]) }
    case "tools/call":
        guard let id else { continue }
        let params = request["params"] as? [String: Any] ?? [:]
        let arguments = params["arguments"] as? [String: Any] ?? [:]
        do {
            let result: String
            switch params["name"] as? String {
            case "quartz_create_task": result = try createTask(arguments: arguments)
            case "quartz_create_note": result = try createPostIt(arguments: arguments)
            case let name?: throw MCPServerError.unknownTool(name)
            case nil: throw MCPServerError.invalidArguments("Le nom de l’outil est obligatoire.")
            }
            response(id: id, result: textResult(result))
        } catch {
            response(id: id, result: textResult(error.localizedDescription, isError: true))
        }
    default:
        if id != nil { protocolError(id: id, code: -32601, message: "Méthode inconnue : \(method)") }
    }
}
