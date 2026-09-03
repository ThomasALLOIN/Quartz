import Darwin
import QuartzKit
import Foundation

var failures: [String] = []
var checksRun = 0

@MainActor
func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    checksRun += 1
    if !condition() { failures.append(message) }
}

var calendar = Calendar(identifier: .gregorian)
calendar.locale = Locale(identifier: "fr_FR")
calendar.firstWeekday = 2
calendar.timeZone = TimeZone(secondsFromGMT: 0)!

@MainActor
func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
    calendar.date(from: DateComponents(year: year, month: month, day: day))!
}

let daily = TodoTask(title: "Quotidienne", startDate: date(2026, 8, 12), recurrence: .daily)
expect(!daily.occurs(on: date(2026, 8, 11), calendar: calendar), "Une tâche quotidienne ne doit pas exister avant son départ")
expect(daily.occurs(on: date(2026, 9, 2), calendar: calendar), "Une tâche quotidienne doit continuer après son départ")

let weekdays = TodoTask(title: "Ouvrée", startDate: date(2026, 8, 10), recurrence: .weekdays)
expect(weekdays.occurs(on: date(2026, 8, 14), calendar: calendar), "Vendredi doit être un jour ouvré")
expect(!weekdays.occurs(on: date(2026, 8, 15), calendar: calendar), "Samedi ne doit pas être un jour ouvré")
expect(!weekdays.occurs(on: date(2026, 8, 16), calendar: calendar), "Dimanche ne doit pas être un jour ouvré")

let weekly = TodoTask(title: "Hebdomadaire", startDate: date(2026, 8, 12), recurrence: .weekly)
expect(weekly.occurs(on: date(2026, 8, 19), calendar: calendar), "La récurrence hebdomadaire doit conserver le jour")
expect(!weekly.occurs(on: date(2026, 8, 20), calendar: calendar), "La récurrence hebdomadaire ne doit pas déborder au lendemain")

let monthEnd = TodoTask(title: "Fin de mois", startDate: date(2024, 1, 31), recurrence: .monthly)
expect(monthEnd.occurs(on: date(2024, 2, 29), calendar: calendar), "Le 31 doit être ramené au dernier jour d’un mois court")
expect(!monthEnd.occurs(on: date(2024, 2, 28), calendar: calendar), "Une année bissextile doit conserver le 29 février")
expect(monthEnd.occurs(on: date(2024, 4, 30), calendar: calendar), "Avril doit utiliser son dernier jour")

let dogHints = FrenchTaskHints.extract(from: "sortir les chiens chaque jours a 19h")
expect(dogHints.recurrence == .daily, "« chaque jours » doit activer la récurrence quotidienne")
expect(dogHints.dueMinutes == 19 * 60, "« à 19h » doit activer l’heure à 19:00")
expect(
    dogHints.cleanedTitle("sortir les chiens chaque jours a 19h") == "Sortir les chiens",
    "La récurrence et l’heure ne doivent pas rester dans le titre"
)

let weekdayHints = FrenchTaskHints.extract(from: "Chaque jour ouvré à 8 h 30, préparer le point")
expect(weekdayHints.recurrence == .weekdays, "« chaque jour ouvré » doit sélectionner les jours ouvrés")
expect(weekdayHints.dueMinutes == 8 * 60 + 30, "Une heure écrite « 8 h 30 » doit être reconnue")
expect(
    FrenchTaskHints.extract(from: "Une fois par semaine, arroser les plantes").recurrence == .weekly,
    "« une fois par semaine » doit activer la récurrence hebdomadaire"
)
expect(
    FrenchTaskHints.extract(from: "Tous les mois payer le loyer").recurrence == .monthly,
    "« tous les mois » doit activer la récurrence mensuelle"
)
expect(
    FrenchTaskHints.extract(from: "Planifier la semaine").recurrence == nil,
    "Le mot semaine dans un titre ne doit pas créer une fausse récurrence"
)
expect(
    FrenchTaskHints.extract(from: "Demain à 25h faire un essai").dueMinutes == nil,
    "Une heure impossible ne doit pas être acceptée"
)

let referenceDate = date(2026, 8, 15)
let tomorrowHints = FrenchTaskHints.extract(
    from: "Demain à 19h sortir les chiens, rappelle-moi 15 minutes avant",
    referenceDate: referenceDate,
    calendar: calendar
)
expect(
    tomorrowHints.startDate == date(2026, 8, 16),
    "« demain » doit primer sur la date proposée par le LLM"
)
expect(tomorrowHints.hasExplicitDate, "Une date française explicite doit être signalée")
expect(tomorrowHints.dueMinutes == 19 * 60, "L’heure cible doit rester 19:00 malgré le rappel")
expect(
    tomorrowHints.reminder == .supported(.fifteenMinutes),
    "« 15 minutes avant » doit imposer le rappel correspondant"
)
expect(
    tomorrowHints.cleanedTitle("Demain à 19h sortir les chiens, rappelle-moi 15 minutes avant")
        == "Sortir les chiens",
    "La date, l’heure et le rappel ne doivent pas rester dans le titre"
)

let afterTomorrow = FrenchTaskHints.extract(
    from: "Après-demain ranger le garage",
    referenceDate: referenceDate,
    calendar: calendar
)
expect(afterTomorrow.startDate == date(2026, 8, 17), "« après-demain » doit ajouter deux jours")

let threeDays = FrenchTaskHints.extract(
    from: "Dans trois jours envoyer le dossier",
    referenceDate: referenceDate,
    calendar: calendar
)
expect(threeDays.startDate == date(2026, 8, 18), "Les nombres français doivent être compris dans une date relative")

let inTwoWeeks = FrenchTaskHints.extract(
    from: "Dans deux semaines contrôler les comptes",
    referenceDate: referenceDate,
    calendar: calendar
)
expect(inTwoWeeks.startDate == date(2026, 8, 29), "Une date exprimée en semaines doit être résolue localement")

let tonight = FrenchTaskHints.extract(
    from: "Ce soir à 20h noter les idées",
    referenceDate: referenceDate,
    calendar: calendar
)
expect(tonight.startDate == referenceDate, "« ce soir » doit désigner la date du jour")

let nextFriday = FrenchTaskHints.extract(
    from: "Vendredi prochain appeler le médecin",
    referenceDate: referenceDate,
    calendar: calendar
)
expect(nextFriday.startDate == date(2026, 8, 21), "Un jour de semaine explicite doit viser sa prochaine occurrence")

let recurringTuesday = FrenchTaskHints.extract(
    from: "Tous les mardis arroser les plantes",
    referenceDate: referenceDate,
    calendar: calendar
)
expect(recurringTuesday.recurrence == .weekly, "« tous les mardis » doit créer une récurrence hebdomadaire")
expect(recurringTuesday.startDate == date(2026, 8, 18), "Une récurrence par jour doit commencer au prochain jour correspondant")

let frenchAbsoluteDate = FrenchTaskHints.extract(
    from: "Le 20 août préparer les valises",
    referenceDate: referenceDate,
    calendar: calendar
)
expect(frenchAbsoluteDate.startDate == date(2026, 8, 20), "Une date française sans année doit viser la prochaine occurrence")

let pastFrenchDate = FrenchTaskHints.extract(
    from: "Le 14 août renouveler le passeport",
    referenceDate: referenceDate,
    calendar: calendar
)
expect(pastFrenchDate.startDate == date(2027, 8, 14), "Une date sans année déjà passée doit viser l’année suivante")

let impossibleDate = FrenchTaskHints.extract(
    from: "Le 31 février 2027 faire le bilan",
    referenceDate: referenceDate,
    calendar: calendar
)
expect(impossibleDate.hasExplicitDate, "Une date impossible doit être détectée comme explicite")
expect(impossibleDate.startDate == nil, "Une date impossible ne doit jamais être inventée")

let oneHourReminder = FrenchTaskHints.extract(
    from: "À 19h appeler Paul avec un rappel 1h avant",
    referenceDate: referenceDate,
    calendar: calendar
)
expect(oneHourReminder.dueMinutes == 19 * 60, "« 1h avant » ne doit pas être confondu avec l’heure 01:00")
expect(oneHourReminder.reminder == .supported(.oneHour), "« 1h avant » doit imposer un rappel d’une heure")

let naturalReminder = FrenchTaskHints.extract(
    from: "Demain à 17h récupérer le costume et me prévenir une heure avant",
    referenceDate: referenceDate,
    calendar: calendar
)
expect(naturalReminder.reminder == .supported(.oneHour), "« me prévenir une heure avant » doit être sécurisé")

let writtenReminder = FrenchTaskHints.extract(
    from: "À 16h appeler le comptable avec un rappel quinze minutes avant",
    referenceDate: referenceDate,
    calendar: calendar
)
expect(writtenReminder.reminder == .supported(.fifteenMinutes), "Un délai écrit en lettres doit être reconnu")

let unsupportedReminder = FrenchTaskHints.extract(
    from: "À 9h appeler Paul, rappelle-moi 10 minutes avant",
    referenceDate: referenceDate,
    calendar: calendar
)
expect(unsupportedReminder.reminder == .unsupported, "Un délai indisponible doit être refusé explicitement")

expect(
    FrenchTaskHints.extract(from: "Acheter du pain et appeler Paul").containsMultipleTasks,
    "Deux actions reliées par « et » doivent être détectées"
)
expect(
    FrenchTaskHints.extract(from: "Réserver le train ; prévenir Marie").containsMultipleTasks,
    "Deux actions séparées par un point-virgule doivent être détectées"
)
expect(
    FrenchTaskHints.extract(from: "- Acheter du pain\n- Appeler Paul").containsMultipleTasks,
    "Une liste de plusieurs actions doit être détectée"
)
expect(
    !FrenchTaskHints.extract(from: "Acheter du pain et du lait").containsMultipleTasks,
    "Deux objets dans une même tâche ne doivent pas devenir deux tâches"
)
expect(
    !FrenchTaskHints.extract(
        from: "Créer une tâche avec les étapes vérifier les chiffres puis envoyer le bilan"
    ).containsMultipleTasks,
    "Des étapes explicitement demandées doivent rester des sous-tâches"
)

let today = date(2026, 8, 12)
let key = LocalDay.key(for: today, calendar: calendar)
let partial = TodoTask(
    title: "Partielle",
    startDate: today,
    subtasks: [
        TodoSubtask(title: "Une", completedDays: [key]),
        TodoSubtask(title: "Deux")
    ]
)
let complete = TodoTask(title: "Terminée", startDate: today, completedDays: [key])
expect(abs(partial.progress(on: today, calendar: calendar) - 0.5) < 0.0001, "Deux sous-tâches dont une terminée doivent donner 50 %")
expect(abs(TaskMetrics.progress(for: [partial, complete], on: today, calendar: calendar) - 0.75) < 0.0001, "La progression moyenne attendue est 75 %")

let dueTask = TodoTask(title: "Échéance", startDate: today, dueMinutes: 14 * 60 + 30)
let dueMinute = calendar.date(byAdding: .minute, value: 14 * 60 + 30, to: today)!
let endOfDueMinute = calendar.date(byAdding: .second, value: 59, to: dueMinute)!
let nextMinute = calendar.date(byAdding: .minute, value: 1, to: dueMinute)!
expect(dueTask.isDueNow(on: today, at: dueMinute, calendar: calendar), "Une tâche doit être active au début de sa minute d’échéance")
expect(dueTask.isDueNow(on: today, at: endOfDueMinute, calendar: calendar), "Une tâche doit rester active jusqu’à la fin de sa minute d’échéance")
expect(!dueTask.isDueNow(on: today, at: nextMinute, calendar: calendar), "La vignette orange doit disparaître à la minute suivante")
let completedDueTask = TodoTask(
    title: "Échéance terminée",
    startDate: today,
    dueMinutes: 14 * 60 + 30,
    completedDays: [key]
)
expect(!completedDueTask.isDueNow(on: today, at: dueMinute, calendar: calendar), "Une tâche déjà terminée ne doit pas déclencher la pastille orange")

let occurrences = TaskMetrics.occurrenceDates(
    for: weekly,
    from: date(2026, 8, 12),
    through: date(2026, 9, 2),
    calendar: calendar
)
expect(occurrences.count == 4, "L’horizon doit contenir quatre mercredis")
expect(LocalDay.key(for: occurrences.last!, calendar: calendar) == "2026-09-02", "La dernière occurrence doit être le 2 septembre")

let descriptionText = "Relire le dossier français\nNoter les points importants"
let describedSubtask = TodoSubtask(title: "Préparer le dossier", description: descriptionText)
expect(describedSubtask.description == descriptionText, "Une sous-tâche doit conserver sa description")

let postItDate = date(2026, 8, 15)
let postIt = PostItNote(
    id: UUID(uuidString: "E9C43CF1-FF4B-458A-BA9A-B2F57EE07B76")!,
    text: "Acheter du lait\nPrendre aussi du pain",
    tone: .sage,
    scope: .daily,
    dayKey: "2026-08-15",
    createdAt: postItDate,
    updatedAt: postItDate
)
expect(PostItTone.allCases.count == 4, "Les quatre anciens tons de post-it doivent rester décodables")
expect(PostItMode.off.next == .persistent, "Le premier clic doit activer les post-it jaunes permanents")
expect(PostItMode.persistent.next == .daily, "Le deuxième clic doit activer les post-it verts daily")
expect(PostItMode.daily.next == .off, "Le troisième clic doit désactiver le mode post-it")
let defaultPostIt = PostItNote(text: "Note jaune")
expect(defaultPostIt.tone == .parchment, "Un nouveau post-it doit utiliser le ton jaune")
expect(defaultPostIt.scope == .persistent, "Un nouveau post-it doit être permanent par défaut")
expect(postIt.isVisible(on: postItDate, calendar: calendar), "Un daily doit apparaître le jour auquel il est lié")
expect(!postIt.isVisible(on: date(2026, 8, 16), calendar: calendar), "Un daily doit disparaître des autres jours")
do {
    let encoded = try JSONEncoder().encode(postIt)
    let decoded = try JSONDecoder().decode(PostItNote.self, from: encoded)
    expect(decoded == postIt, "Un post-it doit survivre à un cycle de sauvegarde complet")
    expect(decoded.text.contains("Prendre aussi du pain"), "Un post-it doit conserver son texte multiligne")
} catch {
    failures.append("La sauvegarde d’un post-it a échoué : \(error)")
}

let legacyPostItJSON = Data(
    #"{"id":"69D1C38C-2CFB-40C7-BC90-09B246674C3A","text":"Ancienne note","tone":"rose","createdAt":0,"updatedAt":0}"#.utf8
)
do {
    let legacyPostIt = try JSONDecoder().decode(PostItNote.self, from: legacyPostItJSON)
    expect(legacyPostIt.scope == .persistent, "Un ancien post-it sans type doit devenir permanent")
    expect(legacyPostIt.dayKey == nil, "Un ancien post-it permanent ne doit pas recevoir de jour")
} catch {
    failures.append("La migration d’un ancien post-it a échoué : \(error)")
}

let legacySubtaskJSON = Data(
    #"{"id":"8B0F9D54-8EA5-41B5-99D5-2F84A6BF94C0","title":"Sous-tâche existante","completedDays":["2026-08-12"]}"#.utf8
)
do {
    let legacySubtask = try JSONDecoder().decode(TodoSubtask.self, from: legacySubtaskJSON)
    expect(legacySubtask.title == "Sous-tâche existante", "Une ancienne sous-tâche doit garder son titre")
    expect(legacySubtask.description == nil, "Une ancienne sous-tâche sans description doit rester lisible")
    expect(legacySubtask.completedDays == ["2026-08-12"], "Une ancienne sous-tâche doit garder ses jours terminés")
} catch {
    failures.append("Le décodage d’une ancienne sous-tâche a échoué : \(error)")
}

do {
    let encoder = JSONEncoder()
    let encoded = try encoder.encode(describedSubtask)
    let decoded = try JSONDecoder().decode(TodoSubtask.self, from: encoded)
    expect(decoded == describedSubtask, "Une description française multiligne doit survivre à la sauvegarde")

    let withoutDescription = try encoder.encode(TodoSubtask(title: "Sans détail"))
    let object = try JSONSerialization.jsonObject(with: withoutDescription) as? [String: Any]
    expect(object?["description"] == nil, "Une description absente ne doit pas alourdir les données sauvegardées")

    let container = TodoTask(title: "Conteneur", startDate: today, subtasks: [describedSubtask])
    let decodedContainer = try JSONDecoder().decode(TodoTask.self, from: encoder.encode(container))
    expect(decodedContainer.subtasks.first?.description == descriptionText, "Une description doit survivre dans une tâche complète")

} catch {
    failures.append("La sauvegarde d’une description de sous-tâche a échoué : \(error)")
}

let externalRequestID = UUID(uuidString: "188E67B1-542B-45B3-95EF-8C3FF9869D0E")!
let externalRequest = ExternalTaskRequest(
    id: externalRequestID,
    createdAt: date(2026, 8, 12),
    source: "claude",
    title: "  Préparer la présentation  ",
    startDate: date(2026, 8, 14),
    dueMinutes: 14 * 60 + 30,
    recurrence: .weekly,
    reminder: .thirtyMinutes,
    notes: "  Réunion de direction  ",
    subtasks: [
        ExternalSubtaskDraft(title: " Relire les chiffres "),
        ExternalSubtaskDraft(title: "Exporter", description: " Version PDF ")
    ]
)

do {
    let imported = try externalRequest.makeTask(calendar: calendar)
    expect(imported.id == externalRequestID, "Une requête externe doit conserver son identifiant idempotent")
    expect(imported.title == "Préparer la présentation", "Le titre externe doit être nettoyé")
    expect(imported.dueMinutes == 870, "L’heure externe doit être conservée en minutes")
    expect(imported.recurrence == .weekly, "La récurrence externe doit être conservée")
    expect(imported.reminder == .thirtyMinutes, "Le rappel externe doit être conservé")
    expect(imported.notes == "Réunion de direction", "Les notes externes doivent être nettoyées")
    expect(imported.subtasks.count == 2, "Les sous-tâches externes doivent être importées")
    expect(imported.subtasks.last?.description == "Version PDF", "La description externe doit être nettoyée")
} catch {
    failures.append("La conversion d’une requête externe valide a échoué : \(error)")
}

do {
    _ = try ExternalTaskRequest(title: "   ", startDate: today).makeTask(calendar: calendar)
    failures.append("Une requête externe sans titre aurait dû être refusée")
} catch ExternalTaskValidationError.emptyTitle {
    expect(true, "Une requête externe vide est refusée")
} catch {
    failures.append("Erreur inattendue pour le titre externe vide : \(error)")
}

do {
    _ = try ExternalTaskRequest(
        title: "Rappel incomplet",
        startDate: today,
        reminder: .fifteenMinutes
    ).makeTask(calendar: calendar)
    failures.append("Un rappel externe sans heure aurait dû être refusé")
} catch ExternalTaskValidationError.reminderRequiresTime {
    expect(true, "Un rappel externe sans heure est refusé")
} catch {
    failures.append("Erreur inattendue pour le rappel externe sans heure : \(error)")
}

do {
    let temporaryRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("quartz-checks-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryRoot) }
    let inbox = ExternalTaskInbox(directoryURL: temporaryRoot.appendingPathComponent("Inbox"))
    let queuedURL = try inbox.enqueue(externalRequest)
    expect(FileManager.default.fileExists(atPath: queuedURL.path), "La boîte locale doit écrire une requête atomique")
    let pending = try inbox.pendingFiles()
    expect(pending.count == 1, "La boîte locale doit lister une requête en attente")
    let decoded = try inbox.decode(pending[0])
    expect(decoded == externalRequest, "Une requête en attente doit survivre au cycle JSON")
    try inbox.markProcessed(pending[0])
    let remaining = try inbox.pendingFiles()
    expect(remaining.isEmpty, "Une requête traitée doit disparaître de la boîte")
} catch {
    failures.append("Le cycle de la boîte de réception locale a échoué : \(error)")
}

do {
    let postItID = UUID(uuidString: "2BCB4FC1-423B-412A-9559-C6AFB3CB1784")!
    let request = ExternalPostItRequest(
        id: postItID,
        createdAt: date(2026, 8, 12),
        source: "mcp",
        text: "  Penser aux fleurs  ",
        scope: .daily,
        date: date(2026, 8, 14)
    )
    let postIt = try request.makePostIt(calendar: calendar)
    expect(postIt.id == postItID, "Un post-it MCP doit conserver son identifiant")
    expect(postIt.text == "Penser aux fleurs", "Le texte d’un post-it MCP doit être nettoyé")
    expect(postIt.scope == .daily, "Le type daily d’un post-it MCP doit être conservé")
    expect(postIt.dayKey == "2026-08-14", "Un post-it daily doit garder sa journée")

    let temporaryRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("quartz-post-it-checks-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryRoot) }
    let inbox = ExternalPostItInbox(directoryURL: temporaryRoot.appendingPathComponent("PostItInbox"))
    let queuedURL = try inbox.enqueue(request)
    expect(FileManager.default.fileExists(atPath: queuedURL.path), "La boîte post-it doit écrire une requête atomique")
    let pending = try inbox.pendingFiles()
    expect(pending.count == 1, "La boîte post-it doit lister une requête en attente")
    let decoded = try inbox.decode(pending[0])
    expect(decoded == request, "Un post-it en attente doit survivre au cycle JSON")
} catch {
    failures.append("Le cycle de la boîte post-it MCP a échoué : \(error)")
}

let overriddenSupport = QuartzPaths.applicationSupportDirectory(
    environment: ["QUARTZ_SUPPORT_DIR": "/private/tmp/quartz-override-check"]
)
expect(
    overriddenSupport.path == "/private/tmp/quartz-override-check",
    "Le dossier de données doit pouvoir être isolé pour les tests d’intégration"
)

do {
    let migrationRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("quartz-migration-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: migrationRoot) }
    let legacyDirectory = migrationRoot.appendingPathComponent("EcrinPreview", isDirectory: true)
    try FileManager.default.createDirectory(at: legacyDirectory, withIntermediateDirectories: true)
    let legacyTasks = legacyDirectory.appendingPathComponent("tasks.json")
    try Data("[]".utf8).write(to: legacyTasks)

    let migratedDirectory = QuartzPaths.applicationSupportDirectory(
        environment: [:],
        applicationSupportRoot: migrationRoot
    )
    expect(migratedDirectory.lastPathComponent == "Quartz", "Le nouveau dossier de données doit s’appeler Quartz")
    expect(
        FileManager.default.fileExists(
            atPath: migratedDirectory.appendingPathComponent("tasks.json").path
        ),
        "Les anciennes tâches doivent être migrées vers Quartz"
    )
} catch {
    failures.append("La migration des anciennes données vers Quartz a échoué : \(error)")
}

if failures.isEmpty {
    print("✓ \(checksRun) contrôles du moteur ont réussi")
} else {
    for failure in failures { fputs("✗ \(failure)\n", stderr) }
    exit(EXIT_FAILURE)
}
