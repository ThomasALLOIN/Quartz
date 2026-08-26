import QuartzKit
import Foundation

struct LLMConnectionConfiguration: Codable, Equatable {
    var endpoint = "http://127.0.0.1:8080/v1"
    var model = "default_model"
    var preferenceSaved = false

    static let localDefault = LLMConnectionConfiguration()

    var migratedToMLX: LLMConnectionConfiguration {
        let usedOllama = endpoint.contains(":11434")
            || model.lowercased().hasPrefix("gemma3")
            || model.lowercased().hasPrefix("smollm2:")
        let usedInitialMLXIdentifier = model == "HuggingFaceTB/SmolLM2-135M-Instruct-Q8-mlx"
        return usedOllama || usedInitialMLXIdentifier ? .localDefault : self
    }
}

enum LLMSendState: Equatable {
    case idle
    case starting
    case sending
    case error(String)
}

enum MLXTaskInterpreter {
    private static let systemPrompt =
        "Tu convertis une demande française en une seule tâche Écrin. "
        + "Réponds uniquement avec un objet JSON valide, sans markdown ni explication. "
        + "Utilise exactement les clés title, date, time, recurrence, reminder, notes et subtasks. "
        + "date vaut null, aujourd'hui, demain ou AAAA-MM-JJ. "
        + "time vaut null ou HH:mm. "
        + "recurrence vaut none, daily, weekdays, weekly ou monthly. "
        + "Chaque jour ou tous les jours impose recurrence daily et doit être retiré du title. "
        + "Toute heure écrite, par exemple à 19h, impose time 19:00 et doit être retirée du title. "
        + "Une date française explicite doit être convertie sans rester dans title. "
        + "reminder vaut none, at-time, 5m, 15m, 30m ou 1h. "
        + "Une demande de rappel explicite doit remplir reminder et être retirée du title. "
        + "La demande contient toujours une seule tâche. "
        + "subtasks est une liste d'objets avec title et éventuellement description."

    static func interpret(
        _ prompt: String,
        configuration: LLMConnectionConfiguration,
        selectedDate: Date,
        referenceDate: Date = Date(),
        calendar: Calendar = .french
    ) async throws -> TodoTask {
        let explicitHints = FrenchTaskHints.extract(
            from: prompt,
            referenceDate: referenceDate,
            calendar: calendar
        )
        guard !explicitHints.containsMultipleTasks else {
            throw MLXTaskError.multipleTasks
        }

        let endpoint = try chatEndpoint(from: configuration.endpoint)
        let body = ChatRequest(
            model: configuration.model.isEmpty ? "default_model" : configuration.model,
            temperature: 0,
            maxTokens: 256,
            messages: [
                Message(role: "system", content: systemPrompt),
                Message(role: "user", content: prompt),
            ]
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw MLXTaskError.serverUnavailable
        }

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode)
        else {
            throw MLXTaskError.serverRejected
        }

        guard
            let completion = try? JSONDecoder().decode(ChatResponse.self, from: data),
            let content = completion.choices.first?.message.content,
            let contentData = content.trimmingCharacters(in: .whitespacesAndNewlines).data(using: .utf8),
            let interpretation = try? JSONDecoder().decode(TaskInterpretation.self, from: contentData)
        else {
            throw MLXTaskError.invalidJSON
        }

        return try interpretation.makeTask(
            explicitHints: explicitHints,
            selectedDate: selectedDate,
            calendar: calendar
        )
    }

    private static func chatEndpoint(from rawValue: String) throws -> URL {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: trimmed),
              components.scheme == "http",
              let host = components.host?.lowercased(),
              ["127.0.0.1", "localhost", "::1"].contains(host)
        else {
            throw MLXTaskError.nonLocalEndpoint
        }

        let cleanPath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if !cleanPath.hasSuffix("chat/completions") {
            components.path = "/" + ([cleanPath, "chat/completions"].filter { !$0.isEmpty }.joined(separator: "/"))
        }
        guard let url = components.url else { throw MLXTaskError.invalidEndpoint }
        return url
    }

}

enum MLXTaskError: LocalizedError {
    case invalidEndpoint
    case nonLocalEndpoint
    case serverUnavailable
    case serverRejected
    case invalidJSON
    case invalidReminder
    case invalidExplicitDate
    case unsupportedExplicitReminder
    case multipleTasks

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint:
            "L’adresse de MLX est invalide."
        case .nonLocalEndpoint:
            "Quartz accepte uniquement un serveur local sur ce Mac."
        case .serverUnavailable:
            "Le moteur local ne répond pas. Quartz tentera de le redémarrer au prochain envoi."
        case .serverRejected:
            "MLX a refusé la demande. Vérifie le modèle configuré."
        case .invalidJSON:
            "La réponse de MLX n’est pas une tâche valide. Reformule la demande."
        case .invalidReminder:
            "Un rappel nécessite une heure précise, par exemple 09:30."
        case .invalidExplicitDate:
            "La date écrite n’existe pas. Corrige-la puis réessaie."
        case .unsupportedExplicitReminder:
            "Ce délai de rappel n’est pas disponible. Utilise 5, 15, 30 minutes ou 1 heure."
        case .multipleTasks:
            "J’ai repéré plusieurs tâches. Envoie-les une par une pour pouvoir vérifier chacune."
        }
    }
}

private struct Message: Codable {
    let role: String
    let content: String
}

private struct ChatRequest: Encodable {
    let model: String
    let temperature: Double
    let maxTokens: Int
    let messages: [Message]

    enum CodingKeys: String, CodingKey {
        case model, temperature, messages
        case maxTokens = "max_tokens"
    }
}

private struct ChatResponse: Decodable {
    struct Choice: Decodable {
        struct ResponseMessage: Decodable {
            let content: String
        }

        let message: ResponseMessage
    }

    let choices: [Choice]
}

private struct TaskInterpretation: Decodable {
    struct Subtask: Decodable {
        let title: String
        let description: String?
    }

    let title: String
    let date: String?
    let time: String?
    let recurrence: String
    let reminder: String
    let notes: String
    let subtasks: [Subtask]

    func makeTask(
        explicitHints: FrenchTaskHints,
        selectedDate: Date,
        calendar: Calendar
    ) throws -> TodoTask {
        let startDate: Date
        if let explicitDate = explicitHints.startDate {
            startDate = explicitDate
        } else if explicitHints.hasExplicitDate {
            throw MLXTaskError.invalidExplicitDate
        } else {
            startDate = calendar.startOfDay(for: selectedDate)
        }
        // Le petit modèle peut inventer un horaire ou une récurrence plausible.
        // Seules les informations réellement présentes dans la phrase sont retenues.
        let dueMinutes = explicitHints.dueMinutes
        let resolvedRecurrence = explicitHints.recurrence ?? .none
        let resolvedReminder: ReminderOption
        switch explicitHints.reminder {
        case .absent:
            resolvedReminder = .none
        case let .supported(explicitReminder):
            resolvedReminder = explicitReminder
        case .unsupported:
            throw MLXTaskError.unsupportedExplicitReminder
        }
        if resolvedReminder != .none, dueMinutes == nil { throw MLXTaskError.invalidReminder }

        let request = ExternalTaskRequest(
            source: "Quartz MLX",
            title: explicitHints.cleanedTitle(title),
            startDate: startDate,
            dueMinutes: dueMinutes,
            recurrence: resolvedRecurrence,
            reminder: resolvedReminder,
            notes: notes,
            subtasks: subtasks.map {
                ExternalSubtaskDraft(title: $0.title, description: $0.description)
            }
        )
        return try request.makeTask(calendar: calendar)
    }

}
