import QuartzKit
import Foundation
import UserNotifications

@MainActor
final class NotificationScheduler {
    private let calendar = Calendar.french

    var isAvailable: Bool {
        Bundle.main.bundleURL.pathExtension.lowercased() == "app"
            && Bundle.main.bundleIdentifier != nil
    }

    private var center: UNUserNotificationCenter? {
        guard isAvailable else { return nil }
        return UNUserNotificationCenter.current()
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        guard let center else { return .notDetermined }
        return await center.notificationSettings().authorizationStatus
    }

    func requestAuthorization() async -> Bool {
        guard let center else { return false }
        do {
            return try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    func clear() {
        center?.removeAllPendingNotificationRequests()
    }

    func reschedule(tasks: [TodoTask], enabled: Bool, soundsEnabled: Bool) async {
        guard let center else { return }
        center.removeAllPendingNotificationRequests()
        guard enabled else { return }

        let now = Date()
        guard let horizon = calendar.date(byAdding: .day, value: 45, to: now) else { return }

        struct Candidate {
            let task: TodoTask
            let occurrence: Date
            let fireDate: Date
        }

        var candidates: [Candidate] = []
        for task in tasks {
            guard task.dueMinutes != nil, let lead = task.reminder.minutesBefore else { continue }
            let dates = TaskMetrics.occurrenceDates(
                for: task,
                from: now,
                through: horizon,
                calendar: calendar
            )
            for occurrence in dates where !task.isCompleted(on: occurrence, calendar: calendar) {
                guard
                    let dueDate = task.dueDate(on: occurrence, calendar: calendar),
                    let fireDate = calendar.date(byAdding: .minute, value: -lead, to: dueDate),
                    fireDate > now
                else { continue }
                candidates.append(Candidate(task: task, occurrence: occurrence, fireDate: fireDate))
            }
        }

        for candidate in candidates.sorted(by: { $0.fireDate < $1.fireDate }).prefix(48) {
            let content = UNMutableNotificationContent()
            content.title = candidate.task.title
            content.body = "Un rendez-vous avec votre journée."
            content.sound = soundsEnabled ? .default : nil

            let components = calendar.dateComponents(
                [.calendar, .timeZone, .year, .month, .day, .hour, .minute],
                from: candidate.fireDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let identifier = "quartz-\(candidate.task.id.uuidString)-\(LocalDay.key(for: candidate.occurrence, calendar: calendar))"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            try? await center.add(request)
        }
    }
}
