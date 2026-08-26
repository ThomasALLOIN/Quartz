import AppKit
import Combine
import QuartzKit
import Foundation
import UserNotifications

struct EditorRequest: Identifiable {
    let id = UUID()
    let taskID: UUID?
    let proposedTask: TodoTask?

    init(taskID: UUID? = nil, proposedTask: TodoTask? = nil) {
        self.taskID = taskID
        self.proposedTask = proposedTask
    }
}

struct StorageNotice: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

@MainActor
final class AppModel: ObservableObject {
    private enum PreferenceKey {
        static let alwaysOnTop = "alwaysOnTop"
        static let notifications = "notificationsEnabled"
        static let sounds = "soundsEnabled"
        static let theme = "stoneTheme"
        static let widgetVisible = "widgetVisible"
        static let llmLocalConfiguration = "llmLocalConfiguration"
        static let legacyLLMConfigurations = "llmConfigurations"
        static let llmEnabled = "llmEnabled"
        static let postItMode = "postItMode"
        static let postItModeSelection = "postItModeSelection"
        static let previewMigrationCompleted = "previewPreferencesMigratedToApp"
    }

    private let calendar = Calendar.french
    private let persistence = TaskPersistence()
    private let notificationScheduler = NotificationScheduler()
    private let postItPersistence = PostItPersistence()
    private let externalTaskInbox = ExternalTaskInboxMonitor()
    private let defaults = UserDefaults.standard

    @Published private(set) var tasks: [TodoTask] {
        didSet {
            reportStorageFailure(persistence.save(tasks), collection: "tâches")
            rescheduleNotifications()
        }
    }
    @Published var selectedDate: Date
    @Published private(set) var isCompact: Bool
    @Published private(set) var isWidgetVisible: Bool
    @Published private(set) var alwaysOnTop: Bool
    @Published private(set) var notificationsEnabled: Bool
    @Published private(set) var soundsEnabled: Bool
    @Published private(set) var theme: StoneTheme
    @Published private(set) var notificationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var notificationIssue: String?
    @Published private(set) var llmConfiguration: LLMConnectionConfiguration
    @Published private(set) var llmEnabled: Bool
    @Published private(set) var postIts: [PostItNote] {
        didSet {
            reportStorageFailure(postItPersistence.save(postIts), collection: "post-it")
        }
    }
    @Published private(set) var postItMode: PostItMode
    @Published private(set) var postItShelfVisible = false
    @Published private(set) var llmSendState: LLMSendState = .idle
    @Published var llmDraft = ""
    @Published var llmComposerPresented = false
    @Published var llmConnectionPresented = false
    @Published var editorRequest: EditorRequest?
    @Published var settingsPresented = false
    @Published var storageNotice: StorageNotice?

    private var postItHoverGeneration = 0
    private var postItShelfPinned = false
    private var llmRequestTask: Task<Void, Never>?

    init() {
        Self.migratePreviewPreferences(in: UserDefaults.standard)

        let initialCalendar = Calendar.french
        let initialDate = initialCalendar.startOfDay(for: Date())
        selectedDate = initialDate
        isCompact = ProcessInfo.processInfo.environment["QUARTZ_START_COMPACT"] == "1"
        if defaults.object(forKey: PreferenceKey.widgetVisible) == nil {
            isWidgetVisible = true
        } else {
            isWidgetVisible = defaults.bool(forKey: PreferenceKey.widgetVisible)
        }

        if defaults.object(forKey: PreferenceKey.alwaysOnTop) == nil {
            alwaysOnTop = true
        } else {
            alwaysOnTop = defaults.bool(forKey: PreferenceKey.alwaysOnTop)
        }

        notificationsEnabled = defaults.bool(forKey: PreferenceKey.notifications)
        soundsEnabled = defaults.bool(forKey: PreferenceKey.sounds)
        theme = StoneTheme(rawValue: defaults.string(forKey: PreferenceKey.theme) ?? "") ?? .lapis
        llmConfiguration = Self.loadLocalLLMConfiguration(
            currentData: defaults.data(forKey: PreferenceKey.llmLocalConfiguration),
            legacyData: defaults.data(forKey: PreferenceKey.legacyLLMConfigurations)
        )
        llmEnabled = defaults.object(forKey: PreferenceKey.llmEnabled) == nil
            ? true
            : defaults.bool(forKey: PreferenceKey.llmEnabled)
        var initialStorageMessages: [String] = []
        switch postItPersistence.load() {
        case .missing:
            postIts = []
        case let .loaded(notes):
            postIts = notes
        case let .recovered(notes, quarantinedFileURL):
            postIts = notes
            initialStorageMessages.append(
                Self.recoveryMessage(
                    collection: "post-it",
                    quarantinedFileURL: quarantinedFileURL
                )
            )
        case let .failed(error):
            postIts = []
            initialStorageMessages.append(Self.failureMessage(collection: "post-it", error: error))
        }
        if
            let rawMode = defaults.string(forKey: PreferenceKey.postItModeSelection),
            let storedMode = PostItMode(rawValue: rawMode)
        {
            postItMode = storedMode
        } else {
            postItMode = defaults.bool(forKey: PreferenceKey.postItMode) ? .persistent : .off
        }

        switch persistence.load() {
        case .missing:
            tasks = Self.demoTasks(for: initialDate, calendar: initialCalendar)
            if let error = persistence.save(tasks) {
                initialStorageMessages.append(Self.failureMessage(collection: "tâches", error: error))
            }
        case let .loaded(storedTasks):
            tasks = storedTasks
        case let .recovered(storedTasks, quarantinedFileURL):
            tasks = storedTasks
            initialStorageMessages.append(
                Self.recoveryMessage(
                    collection: "tâches",
                    quarantinedFileURL: quarantinedFileURL
                )
            )
        case let .failed(error):
            tasks = []
            initialStorageMessages.append(Self.failureMessage(collection: "tâches", error: error))
        }

        if defaults.string(forKey: PreferenceKey.theme) != theme.rawValue {
            defaults.set(theme.rawValue, forKey: PreferenceKey.theme)
        }

        if !initialStorageMessages.isEmpty {
            storageNotice = StorageNotice(
                title: "Quartz a protégé vos données",
                message: initialStorageMessages.joined(separator: "\n\n")
            )
        }

        WindowCoordinator.shared.onVisibilityChange = { [weak self] visible in
            self?.synchronizeWidgetVisibility(visible)
        }

        externalTaskInbox.start { [weak self] request in
            try self?.importExternalTask(request)
        }

        Task {
            await refreshNotificationStatus()
            let report = await notificationScheduler.reschedule(
                tasks: tasks,
                enabled: notificationsEnabled,
                soundsEnabled: soundsEnabled
            )
            applyNotificationReport(report)
        }
    }

    private static func migratePreviewPreferences(in defaults: UserDefaults) {
        guard
            Bundle.main.bundleURL.pathExtension.lowercased() == "app",
            defaults.object(forKey: PreferenceKey.previewMigrationCompleted) == nil
        else { return }

        if let previewPreferences = defaults.persistentDomain(forName: "QuartzPreview") {
            for (key, value) in previewPreferences where defaults.object(forKey: key) == nil {
                defaults.set(value, forKey: key)
            }
        }

        defaults.set(true, forKey: PreferenceKey.previewMigrationCompleted)
    }

    var visibleTasks: [TodoTask] {
        tasks
            .filter { $0.occurs(on: selectedDate, calendar: calendar) }
            .sorted { lhs, rhs in
                switch (lhs.dueMinutes, rhs.dueMinutes) {
                case let (left?, right?): left == right ? lhs.createdAt < rhs.createdAt : left < right
                case (.some, .none): true
                case (.none, .some): false
                case (.none, .none): lhs.createdAt < rhs.createdAt
                }
            }
    }

    func tasksDueNow(at now: Date = Date()) -> [TodoTask] {
        let today = calendar.startOfDay(for: now)
        return tasks
            .filter { $0.isDueNow(on: today, at: now, calendar: calendar) }
            .sorted { lhs, rhs in
                if lhs.dueMinutes == rhs.dueMinutes {
                    return lhs.createdAt < rhs.createdAt
                }
                return (lhs.dueMinutes ?? Int.max) < (rhs.dueMinutes ?? Int.max)
            }
    }

    var postItModeEnabled: Bool {
        postItMode != .off
    }

    var visiblePostIts: [PostItNote] {
        postIts(on: selectedDate)
    }

    var shelfPostIts: [PostItNote] {
        switch postItMode {
        case .off:
            []
        case .persistent:
            postIts.filter { $0.scope == .persistent }
        case .daily:
            postIts.filter {
                $0.scope == .daily && $0.isVisible(on: selectedDate, calendar: calendar)
            }
        }
    }

    func postIts(on date: Date) -> [PostItNote] {
        postIts.filter { $0.isVisible(on: date, calendar: calendar) }
    }

    var dayProgress: Double {
        TaskMetrics.progress(for: tasks, on: selectedDate, calendar: calendar)
    }

    var dayProgressPercent: Int {
        Int((dayProgress * 100).rounded())
    }

    var completedCount: Int {
        TaskMetrics.completedCount(for: tasks, on: selectedDate, calendar: calendar)
    }

    var remainingCount: Int {
        visibleTasks.filter { !$0.isCompleted(on: selectedDate, calendar: calendar) }.count
    }

    var inProgressCount: Int {
        visibleTasks.filter {
            let value = $0.progress(on: selectedDate, calendar: calendar)
            return value > 0 && value < 1
        }.count
    }

    var hasOverdueTask: Bool {
        guard calendar.isDateInToday(selectedDate) else { return false }
        return visibleTasks.contains { task in
            guard
                !task.isCompleted(on: selectedDate, calendar: calendar),
                let due = task.dueDate(on: selectedDate, calendar: calendar)
            else { return false }
            return due < Date()
        }
    }

    var progressDescription: String {
        if visibleTasks.isEmpty { return "Aucune tâche aujourd’hui" }
        if dayProgress >= 1 { return "Tout est accompli aujourd’hui" }
        if inProgressCount > 0 {
            return "\(completedCount) terminée\(completedCount > 1 ? "s" : ""), \(inProgressCount) en cours"
        }
        return "\(remainingCount) à faire aujourd’hui"
    }

    var notificationStatusLabel: String {
        guard notificationsAvailable else {
            return "Disponible dans le .app après validation"
        }
        if let notificationIssue { return notificationIssue }
        return switch notificationStatus {
        case .authorized, .provisional, .ephemeral: "Autorisées par macOS"
        case .denied: "Refusées dans Réglages Système"
        case .notDetermined: "Autorisation requise au premier rappel"
        @unknown default: "État inconnu"
        }
    }

    var notificationsAvailable: Bool {
        notificationScheduler.isAvailable
    }

    var isLLMPreferenceSaved: Bool {
        llmConfiguration.preferenceSaved
    }

    var llmConnectionStatus: String {
        guard llmEnabled else { return "désactivée" }
        return switch llmSendState {
        case .idle: isLLMPreferenceSaved ? "MLX local" : "réglage par défaut"
        case .starting: "démarrage du modèle…"
        case .sending: "analyse en cours…"
        case .error: "à reformuler"
        }
    }

    var llmRuntimeStatusLabel: String {
        guard llmEnabled else {
            return "Le modèle ne peut pas démarrer ni analyser de demande."
        }
        if LocalMLXRuntime.shared.isRuntimeInstalled {
            return "Modèle français intégré et moteur MLX prêt sur ce Mac."
        }
        return "Modèle français intégré ; le moteur MLX-LM doit encore être installé sur ce Mac."
    }

    var isLLMSending: Bool {
        llmSendState == .starting || llmSendState == .sending
    }

    var llmErrorMessage: String? {
        guard case let .error(message) = llmSendState else { return nil }
        return message
    }

    func task(withID id: UUID?) -> TodoTask? {
        guard let id else { return nil }
        return tasks.first { $0.id == id }
    }

    func task(for request: EditorRequest) -> TodoTask? {
        request.proposedTask ?? task(withID: request.taskID)
    }

    func openNewTask() {
        if postItModeEnabled {
            openPostItBoard()
            return
        }
        let delay = isCompact ? 0.22 : 0.06
        revealExpandedWidget()
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.editorRequest = EditorRequest(taskID: nil)
        }
    }

    func openEditor(for task: TodoTask) {
        let delay = isCompact ? 0.22 : 0.06
        let taskID = task.id
        revealExpandedWidget()
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.editorRequest = EditorRequest(taskID: taskID)
        }
    }

    func openSettings() {
        let delay = isCompact ? 0.22 : 0.06
        revealExpandedWidget()
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.settingsPresented = true
        }
    }

    func toggleLLMComposer() {
        llmComposerPresented.toggle()
        if llmComposerPresented, case .error = llmSendState {
            llmSendState = .idle
        }
    }

    func closeLLMComposer() {
        llmComposerPresented = false
    }

    func openLLMConnection() {
        llmConnectionPresented = true
    }

    func prepareLLMSend() {
        let prompt = llmDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard llmEnabled, !prompt.isEmpty, !isLLMSending else { return }

        llmSendState = .starting
        let configuration = llmConfiguration.migratedToMLX
        let date = selectedDate
        // La destination affichée au moment de l’envoi reste la destination finale,
        // même si le bouton post-it change pendant que MLX réfléchit.
        let destination = postItMode
        llmRequestTask = Task { [weak self] in
            do {
                try await LocalMLXRuntime.shared.ensureRunning(configuration: configuration)
                try Task.checkCancellation()
                guard let self else { return }
                llmSendState = .sending
                let proposal = try await MLXTaskInterpreter.interpret(
                    prompt,
                    configuration: configuration,
                    selectedDate: date
                )
                try Task.checkCancellation()
                llmDraft = ""
                llmSendState = .idle
                llmRequestTask = nil
                llmComposerPresented = false
                switch destination {
                case .off:
                    editorRequest = EditorRequest(proposedTask: proposal)
                case .persistent, .daily:
                    addPostIt(
                        text: Self.postItText(from: proposal),
                        day: proposal.startDate,
                        mode: destination
                    )
                }
            } catch is CancellationError {
                self?.llmSendState = .idle
                self?.llmRequestTask = nil
            } catch {
                self?.llmSendState = .error(
                    (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                )
                self?.llmRequestTask = nil
            }
        }
    }

    func setLLMEnabled(_ enabled: Bool) {
        guard llmEnabled != enabled else { return }
        llmEnabled = enabled
        defaults.set(enabled, forKey: PreferenceKey.llmEnabled)
        llmSendState = .idle

        if !enabled {
            llmRequestTask?.cancel()
            llmRequestTask = nil
            LocalMLXRuntime.shared.stop()
        }
    }

    func saveLLMConfiguration(_ configuration: LLMConnectionConfiguration) {
        let migrated = configuration.migratedToMLX
        llmConfiguration = migrated
        llmSendState = .idle
        guard let data = try? JSONEncoder().encode(migrated) else { return }
        defaults.set(data, forKey: PreferenceKey.llmLocalConfiguration)
    }

    func addQuickEntry(title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if postItModeEnabled {
            addPostIt(text: trimmed)
        } else {
            tasks.append(TodoTask(title: trimmed, startDate: selectedDate))
        }
    }

    func togglePostItMode() {
        setPostItMode(postItMode.next)
    }

    func setPostItMode(_ enabled: Bool) {
        setPostItMode(enabled ? .persistent : .off)
    }

    func setPostItMode(_ mode: PostItMode) {
        postItMode = mode
        defaults.set(mode.rawValue, forKey: PreferenceKey.postItModeSelection)
        defaults.set(mode != .off, forKey: PreferenceKey.postItMode)
        if mode != .off {
            DispatchQueue.main.async {
                WindowCoordinator.shared.reserveLeftSpaceForPostIts()
            }
        } else {
            hidePostItShelf()
        }
    }

    func openPostItBoard() {
        let delay = isCompact ? 0.22 : 0.0
        if !postItModeEnabled {
            setPostItMode(.persistent)
        }
        revealExpandedWidget()
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            WindowCoordinator.shared.reserveLeftSpaceForPostIts()
            self?.showPostItShelf(pinned: true)
        }
    }

    func openPostItBoard(showing scope: PostItScope) {
        setPostItMode(scope == .daily ? .daily : .persistent)
        openPostItBoard()
    }

    func preparePostItLayout() {
        guard postItModeEnabled, !isCompact else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            WindowCoordinator.shared.reserveLeftSpaceForPostIts()
        }
    }

    func setPostItTriggerHovered(_ hovering: Bool) {
        guard postItModeEnabled else {
            hidePostItShelf()
            return
        }
        if hovering {
            showPostItShelf()
        } else {
            schedulePostItShelfHide()
        }
    }

    func setPostItShelfHovered(_ hovering: Bool) {
        if hovering {
            showPostItShelf()
        } else {
            schedulePostItShelfHide()
        }
    }

    func showPostItShelf(pinned: Bool = false) {
        guard postItModeEnabled else { return }
        postItHoverGeneration += 1
        if pinned {
            postItShelfPinned = true
        }
        postItShelfVisible = true
    }

    func hidePostItShelf() {
        postItHoverGeneration += 1
        postItShelfPinned = false
        postItShelfVisible = false
    }

    func addPostIt(text: String, day: Date? = nil, mode: PostItMode? = nil) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let capturedMode = mode ?? postItMode
        let scope: PostItScope = capturedMode == .daily ? .daily : .persistent
        let targetDate = day ?? selectedDate
        postIts.insert(
            PostItNote(
                text: trimmed,
                tone: scope == .daily ? .sage : .parchment,
                scope: scope,
                dayKey: scope == .daily
                    ? LocalDay.key(for: targetDate, calendar: calendar)
                    : nil
            ),
            at: 0
        )
    }

    func updatePostIt(id: UUID, text: String) {
        guard let index = postIts.firstIndex(where: { $0.id == id }) else { return }
        postIts[index].text = text
        postIts[index].updatedAt = Date()
    }

    func deletePostIt(id: UUID) {
        postIts.removeAll { $0.id == id }
    }

    func save(_ task: TodoTask) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = task
        } else {
            tasks.append(task)
        }
    }

    func delete(_ task: TodoTask) {
        tasks.removeAll { $0.id == task.id }
    }

    func toggleTask(_ task: TodoTask) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        let dayKey = LocalDay.key(for: selectedDate, calendar: calendar)
        var updatedTask = tasks[index]
        let willComplete = !updatedTask.completedDays.contains(dayKey)

        if willComplete {
            updatedTask.completedDays.insert(dayKey)
            for subtaskIndex in updatedTask.subtasks.indices {
                updatedTask.subtasks[subtaskIndex].completedDays.insert(dayKey)
            }
        } else {
            updatedTask.completedDays.remove(dayKey)
            for subtaskIndex in updatedTask.subtasks.indices {
                updatedTask.subtasks[subtaskIndex].completedDays.remove(dayKey)
            }
        }

        // Une seule publication, sauvegarde et replanification de notifications,
        // même lorsque la tâche contient plusieurs sous-tâches.
        tasks[index] = updatedTask
        if willComplete { playCompletionSound() }
    }

    func toggleSubtask(taskID: UUID, subtaskID: UUID) {
        guard
            let taskIndex = tasks.firstIndex(where: { $0.id == taskID }),
            let subtaskIndex = tasks[taskIndex].subtasks.firstIndex(where: { $0.id == subtaskID })
        else { return }

        let dayKey = LocalDay.key(for: selectedDate, calendar: calendar)
        var updatedTask = tasks[taskIndex]
        let willComplete = !updatedTask.subtasks[subtaskIndex].completedDays.contains(dayKey)
        if willComplete {
            updatedTask.subtasks[subtaskIndex].completedDays.insert(dayKey)
        } else {
            updatedTask.subtasks[subtaskIndex].completedDays.remove(dayKey)
        }

        let allComplete = !updatedTask.subtasks.isEmpty
            && updatedTask.subtasks.allSatisfy { $0.completedDays.contains(dayKey) }
        if allComplete {
            updatedTask.completedDays.insert(dayKey)
        } else {
            updatedTask.completedDays.remove(dayKey)
        }

        tasks[taskIndex] = updatedTask
        if willComplete { playCompletionSound() }
    }

    func completeAllSubtasks(_ task: TodoTask) {
        guard
            let taskIndex = tasks.firstIndex(where: { $0.id == task.id }),
            !tasks[taskIndex].subtasks.isEmpty
        else { return }

        let dayKey = LocalDay.key(for: selectedDate, calendar: calendar)
        var updatedTask = tasks[taskIndex]
        let hasIncompleteSubtask = updatedTask.subtasks.contains {
            !$0.completedDays.contains(dayKey)
        }
        guard hasIncompleteSubtask else { return }

        for subtaskIndex in updatedTask.subtasks.indices {
            updatedTask.subtasks[subtaskIndex].completedDays.insert(dayKey)
        }
        updatedTask.completedDays.insert(dayKey)

        // Une seule publication pour que l'action reste immédiate, même avec
        // une longue liste de sous-tâches.
        tasks[taskIndex] = updatedTask
        playCompletionSound()
    }

    func moveDay(by value: Int) {
        guard let next = calendar.date(byAdding: .day, value: value, to: selectedDate) else { return }
        selectedDate = calendar.startOfDay(for: next)
    }

    func goToToday() {
        selectedDate = calendar.startOfDay(for: Date())
    }

    func select(_ date: Date) {
        selectedDate = calendar.startOfDay(for: date)
    }

    func setCompact(_ compact: Bool) {
        guard compact != isCompact else { return }
        if compact {
            llmComposerPresented = false
            hidePostItShelf()
        }
        isCompact = compact
        WindowCoordinator.shared.resize(compact: compact)
    }

    func setWidgetVisible(_ visible: Bool) {
        if !visible {
            hidePostItShelf()
        }
        isWidgetVisible = visible
        defaults.set(visible, forKey: PreferenceKey.widgetVisible)
        WindowCoordinator.shared.setVisible(visible)
    }

    func synchronizeWidgetVisibility(_ visible: Bool) {
        guard isWidgetVisible != visible else { return }
        isWidgetVisible = visible
        defaults.set(visible, forKey: PreferenceKey.widgetVisible)
    }

    func setAlwaysOnTop(_ enabled: Bool) {
        alwaysOnTop = enabled
        defaults.set(enabled, forKey: PreferenceKey.alwaysOnTop)
        WindowCoordinator.shared.applyAlwaysOnTop(enabled)
    }

    func setSoundsEnabled(_ enabled: Bool) {
        soundsEnabled = enabled
        defaults.set(enabled, forKey: PreferenceKey.sounds)
        rescheduleNotifications()
    }

    func setTheme(_ newTheme: StoneTheme) {
        theme = newTheme
        defaults.set(newTheme.rawValue, forKey: PreferenceKey.theme)
    }

    func setNotificationsEnabled(_ enabled: Bool) {
        if !enabled {
            notificationsEnabled = false
            notificationIssue = nil
            defaults.set(false, forKey: PreferenceKey.notifications)
            notificationScheduler.clear()
            return
        }

        guard notificationsAvailable else {
            notificationsEnabled = false
            defaults.set(false, forKey: PreferenceKey.notifications)
            return
        }

        Task {
            let granted = await notificationScheduler.requestAuthorization()
            notificationsEnabled = granted
            defaults.set(granted, forKey: PreferenceKey.notifications)
            await refreshNotificationStatus()
            let report = await notificationScheduler.reschedule(
                tasks: tasks,
                enabled: granted,
                soundsEnabled: soundsEnabled
            )
            applyNotificationReport(report)
        }
    }

    func refreshNotificationStatus() async {
        notificationStatus = await notificationScheduler.authorizationStatus()
    }

    func revealDataFolder() {
        let directory = persistence.dataDirectoryURL
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        NSWorkspace.shared.open(directory)
    }

    private func reportStorageFailure(
        _ error: JSONFileStoreFailure?,
        collection: String
    ) {
        guard let error else { return }
        let message = Self.failureMessage(collection: collection, error: error)
        if let current = storageNotice {
            guard !current.message.contains(message) else { return }
            storageNotice = StorageNotice(
                title: "Quartz n’a pas pu tout enregistrer",
                message: current.message + "\n\n" + message
            )
        } else {
            storageNotice = StorageNotice(
                title: "Quartz n’a pas pu enregistrer",
                message: message
            )
        }
    }

    private static func recoveryMessage(
        collection: String,
        quarantinedFileURL: URL?
    ) -> String {
        let preserved = quarantinedFileURL == nil
            ? "La sauvegarde précédente a été restaurée."
            : "Le fichier illisible a été conservé dans Recovery et la sauvegarde précédente a été restaurée."
        return "Quartz a récupéré les \(collection). \(preserved)"
    }

    private static func failureMessage(
        collection: String,
        error: JSONFileStoreFailure
    ) -> String {
        let preserved = error.recoveryFileURL == nil
            ? "Le fichier existant n’a pas été supprimé."
            : "Une copie du fichier illisible a été conservée dans Recovery."
        return "Quartz n’a pas pu charger ou enregistrer les \(collection). \(preserved)"
    }

    private func rescheduleNotifications() {
        Task {
            let report = await notificationScheduler.reschedule(
                tasks: tasks,
                enabled: notificationsEnabled,
                soundsEnabled: soundsEnabled
            )
            applyNotificationReport(report)
        }
    }

    private func applyNotificationReport(_ report: NotificationSchedulingReport) {
        if report.failedCount > 0 {
            notificationIssue = "\(report.failedCount) rappel\(report.failedCount > 1 ? "s" : "") non planifié\(report.failedCount > 1 ? "s" : "")."
        } else if report.pendingLimitReached {
            notificationIssue = "\(report.scheduledCount) prochains rappels planifiés ; la file se renouvelle à chaque ouverture ou modification."
        } else {
            notificationIssue = nil
        }
    }

    private func playCompletionSound() {
        guard soundsEnabled else { return }
        NSSound(named: NSSound.Name("Glass"))?.play()
    }

    private func importExternalTask(_ request: ExternalTaskRequest) throws {
        let importedTask = try request.makeTask(calendar: calendar)
        if postItModeEnabled {
            guard !postIts.contains(where: { $0.id == request.id }) else { return }
            let scope: PostItScope = postItMode == .daily ? .daily : .persistent
            postIts.insert(
                PostItNote(
                    id: request.id,
                    text: Self.postItText(from: importedTask),
                    tone: scope == .daily ? .sage : .parchment,
                    scope: scope,
                    dayKey: scope == .daily
                        ? LocalDay.key(for: importedTask.startDate, calendar: calendar)
                        : nil,
                    createdAt: request.createdAt,
                    updatedAt: request.createdAt
                ),
                at: 0
            )
        } else {
            guard !tasks.contains(where: { $0.id == request.id }) else { return }
            tasks.append(importedTask)
        }
    }

    private func revealExpandedWidget() {
        setWidgetVisible(true)
        setCompact(false)
    }

    private func schedulePostItShelfHide() {
        guard !postItShelfPinned else { return }
        postItHoverGeneration += 1
        let generation = postItHoverGeneration
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) { [weak self] in
            guard self?.postItHoverGeneration == generation else { return }
            self?.postItShelfVisible = false
        }
    }

    private static func loadLocalLLMConfiguration(
        currentData: Data?,
        legacyData: Data?
    ) -> LLMConnectionConfiguration {
        if
            let currentData,
            let configuration = try? JSONDecoder().decode(
                LLMConnectionConfiguration.self,
                from: currentData
            )
        {
            return configuration.migratedToMLX
        }

        if
            let legacyData,
            let configurations = try? JSONDecoder().decode(
                [String: LLMConnectionConfiguration].self,
                from: legacyData
            ),
            let localConfiguration = configurations["local"]
        {
            return localConfiguration.migratedToMLX
        }

        return .localDefault
    }

    private static func postItText(from task: TodoTask) -> String {
        var lines = [task.title]
        let notes = task.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !notes.isEmpty { lines.append(notes) }
        lines.append(contentsOf: task.subtasks.map { subtask in
            let description = subtask.description?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return description.isEmpty
                ? "• \(subtask.title)"
                : "• \(subtask.title) — \(description)"
        })
        return lines.joined(separator: "\n")
    }

    private static func demoTasks(for today: Date, calendar: Calendar) -> [TodoTask] {
        let dayKey = LocalDay.key(for: today, calendar: calendar)
        return [
            TodoTask(
                title: "Préparer le rendez-vous",
                startDate: today,
                dueMinutes: 9 * 60 + 30,
                reminder: .fifteenMinutes,
                subtasks: [
                    TodoSubtask(title: "Relire les notes", completedDays: [dayKey]),
                    TodoSubtask(title: "Préparer les documents", completedDays: [dayKey]),
                    TodoSubtask(
                        title: "Confirmer l’adresse",
                        description: "Vérifier le bâtiment et l’étage avant le départ"
                    )
                ]
            ),
            TodoTask(
                title: "Marcher vingt minutes",
                startDate: today,
                dueMinutes: 18 * 60,
                recurrence: .daily,
                reminder: .atTime
            ),
            TodoTask(
                title: "Classer les idées de la semaine",
                startDate: today,
                completedDays: [dayKey]
            )
        ]
    }
}
