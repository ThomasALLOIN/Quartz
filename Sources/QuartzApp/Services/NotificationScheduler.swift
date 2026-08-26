import QuartzKit
import Foundation
import UserNotifications

struct NotificationSchedulingReport: Equatable {
    let scheduledCount: Int
    let failedCount: Int
    let pendingLimitReached: Bool

    static let empty = NotificationSchedulingReport(
        scheduledCount: 0,
        failedCount: 0,
        pendingLimitReached: false
    )
}

@MainActor
final class NotificationScheduler {
    private let calendar = Calendar.french
    private let planningHorizonDays = 365
    private let pendingLimit = 56

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

    func reschedule(
        tasks: [TodoTask],
        enabled: Bool,
        soundsEnabled: Bool
    ) async -> NotificationSchedulingReport {
        guard let center else { return .empty }
        center.removeAllPendingNotificationRequests()
        guard enabled else { return .empty }

        let now = Date()
        guard let horizon = calendar.date(
            byAdding: .day,
            value: planningHorizonDays,
            to: now
        ) else { return .empty }

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

        let orderedCandidates = candidates.sorted { $0.fireDate < $1.fireDate }
        var scheduledCount = 0
        var failedCount = 0

        for candidate in orderedCandidates.prefix(pendingLimit) {
            let dayKey = LocalDay.key(for: candidate.occurrence, calendar: calendar)
            let content = UNMutableNotificationContent()
            content.title = candidate.task.title
            content.body = "Un rendez-vous avec votre journée."
            content.sound = soundsEnabled ? .default : nil
            content.userInfo = [
                "taskID": candidate.task.id.uuidString,
                "dayKey": dayKey,
            ]

            let components = calendar.dateComponents(
                [.calendar, .timeZone, .year, .month, .day, .hour, .minute],
                from: candidate.fireDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let identifier = "quartz-\(candidate.task.id.uuidString)-\(dayKey)"
            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: trigger
            )
            do {
                try await center.add(request)
                scheduledCount += 1
            } catch {
                failedCount += 1
            }
        }

        return NotificationSchedulingReport(
            scheduledCount: scheduledCount,
            failedCount: failedCount,
            pendingLimitReached: orderedCandidates.count > pendingLimit
        )
    }
}
