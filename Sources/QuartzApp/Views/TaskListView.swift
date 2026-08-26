import QuartzKit
import SwiftUI

struct TaskListView: View {
    @EnvironmentObject private var model: AppModel
    let palette: StonePalette
    @State private var expandedTasks: Set<UUID> = []

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                if !model.visiblePostIts.isEmpty {
                    PersistentPostItSection(palette: palette)
                        .padding(.bottom, 4)
                }

                if model.visibleTasks.isEmpty {
                    EmptyDayView(palette: palette)
                        .padding(.top, model.visiblePostIts.isEmpty ? 14 : 6)
                } else {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        ForEach(model.visibleTasks) { task in
                            TaskRowView(
                                task: task,
                                palette: palette,
                                now: context.date,
                                isExpanded: expandedTasks.contains(task.id),
                                onToggleExpansion: {
                                    if expandedTasks.contains(task.id) {
                                        expandedTasks.remove(task.id)
                                    } else {
                                        expandedTasks.insert(task.id)
                                    }
                                }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .scrollIndicators(.never)
        .frame(maxHeight: .infinity)
    }
}

private struct PersistentPostItSection: View {
    @EnvironmentObject private var model: AppModel
    let palette: StonePalette

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Image(systemName: "note.text")
                    .foregroundStyle(palette.accent)
                Text("Post-it · toujours & daily")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(palette.secondary)
                    .lineLimit(1)
                Spacer()
                Text("\(model.visiblePostIts.count)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.accent)
            }
            .padding(.horizontal, 3)

            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    ForEach(model.visiblePostIts) { note in
                        PersistentPostItCard(note: note)
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.never)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Post-it visibles pour cette journée")
    }
}

private struct PersistentPostItCard: View {
    @EnvironmentObject private var model: AppModel
    let note: PostItNote
    @State private var isHovering = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button {
                model.openPostItBoard(showing: note.scope)
            } label: {
                VStack(alignment: .leading, spacing: 5) {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(note.tone.inkColor.opacity(0.48))
                    Text(note.text)
                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                        .foregroundStyle(note.tone.inkColor)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                    Spacer(minLength: 0)
                }
                .padding(8)
                .frame(width: 128, height: 64, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(note.tone.paperColor)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.34), lineWidth: 0.7)
                }
            }
            .buttonStyle(.plain)
            .help("Afficher et modifier les post-it")

            Button {
                withAnimation(.easeOut(duration: 0.14)) {
                    model.deletePostIt(id: note.id)
                }
            } label: {
                Image(systemName: "trash.fill")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Color.red.opacity(0.82)))
            }
            .buttonStyle(.plain)
            .padding(6)
            .opacity(isHovering ? 1 : 0)
            .scaleEffect(isHovering ? 1 : 0.78)
            .allowsHitTesting(isHovering)
            .accessibilityHidden(!isHovering)
            .help("Supprimer ce post-it")
        }
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovering)
    }
}

struct EmptyDayView: View {
    @EnvironmentObject private var model: AppModel
    let palette: StonePalette

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                StoneFill(palette: palette, compact: true)
                    .clipShape(StoneShape())
                Image(systemName: "leaf")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.88))
            }
            .frame(width: 44, height: 34)

            Text("Une journée libre")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(palette.text)
            Text("Ajoutez ce qui mérite votre attention.")
                .font(.system(size: 11))
                .foregroundStyle(palette.secondary)
            Button("Créer une tâche") {
                model.openNewTask()
            }
            .buttonStyle(.borderedProminent)
            .tint(palette.accent)
        }
        .frame(maxWidth: .infinity)
    }
}

struct TaskRowView: View {
    @EnvironmentObject private var model: AppModel
    let task: TodoTask
    let palette: StonePalette
    let now: Date
    let isExpanded: Bool
    let onToggleExpansion: () -> Void
    @State private var isHovering = false

    private var isCompleted: Bool {
        task.isCompleted(on: model.selectedDate, calendar: .french)
    }

    private var progress: Double {
        task.progress(on: model.selectedDate, calendar: .french)
    }

    private var isOverdue: Bool {
        let calendar = Calendar.french
        guard
            calendar.isDateInToday(model.selectedDate),
            !isCompleted,
            let due = task.dueDate(on: model.selectedDate, calendar: calendar)
        else { return false }
        return due < now && !isDueNow
    }

    private var isDueNow: Bool {
        task.isDueNow(on: model.selectedDate, at: now, calendar: .french)
    }

    private var allSubtasksCompleted: Bool {
        !task.subtasks.isEmpty && task.subtasks.allSatisfy {
            $0.isCompleted(on: model.selectedDate, calendar: .french)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 7) {
                CompletionButton(
                    completed: isCompleted,
                    partialProgress: progress,
                    palette: palette,
                    action: { model.toggleTask(task) }
                )
                .accessibilityIdentifier("task-checkbox-\(task.id.uuidString)")
                .padding(.top, 2)

                Button {
                    model.openEditor(for: task)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(task.title)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(isCompleted ? palette.secondary : palette.text)
                            .strikethrough(isCompleted, color: palette.secondary)
                            .lineLimit(2)

                        HStack(spacing: 5) {
                            if let dueMinutes = task.dueMinutes {
                                TaskBadge(
                                    icon: isDueNow
                                        ? "bell.badge.fill"
                                        : (isOverdue ? "exclamationmark.circle.fill" : "clock"),
                                    text: isDueNow
                                        ? "Maintenant · \(timeLabel(dueMinutes))"
                                        : (isOverdue ? "En retard · \(timeLabel(dueMinutes))" : timeLabel(dueMinutes)),
                                    color: isDueNow ? Color.white : (isOverdue ? Color.orange : palette.secondary)
                                )
                            }
                            if let recurrence = task.recurrence.shortLabel {
                                TaskBadge(icon: "arrow.triangle.2.circlepath", text: recurrence, color: palette.secondary)
                            }
                            if task.reminder != .none {
                                Image(systemName: "bell.fill")
                                    .font(.system(size: 9))
                                    .foregroundStyle(palette.secondary)
                                    .accessibilityLabel("Rappel activé")
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                HStack(spacing: 3) {
                    TaskHoverActionButton(
                        icon: "pencil",
                        fill: Color.gray.opacity(0.78),
                        help: "Modifier les réglages de la tâche",
                        action: { model.openEditor(for: task) }
                    )

                    TaskHoverActionButton(
                        icon: "trash.fill",
                        fill: Color.red.opacity(0.82),
                        help: "Supprimer la tâche"
                    ) {
                        withAnimation(.easeOut(duration: 0.14)) {
                            model.delete(task)
                        }
                    }

                    if !task.subtasks.isEmpty {
                        TaskHoverActionButton(
                            icon: "checkmark",
                            fill: Color.green.opacity(allSubtasksCompleted ? 0.34 : 0.78),
                            help: allSubtasksCompleted
                                ? "Toutes les sous-tâches sont terminées"
                                : "Terminer toutes les sous-tâches",
                            disabled: allSubtasksCompleted,
                            action: { model.completeAllSubtasks(task) }
                        )

                        TaskHoverActionButton(
                            icon: "chevron.down",
                            fill: .clear,
                            border: Color.white.opacity(0.78),
                            rotation: isExpanded ? 180 : 0,
                            help: isExpanded ? "Masquer les sous-tâches" : "Afficher les sous-tâches",
                            action: onToggleExpansion
                        )
                    }
                }
                .opacity(isHovering ? 1 : 0)
                .scaleEffect(isHovering ? 1 : 0.86, anchor: .trailing)
                .allowsHitTesting(isHovering)
                .accessibilityHidden(!isHovering)
                .animation(.easeOut(duration: 0.13), value: isHovering)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 7)

            if isExpanded, !task.subtasks.isEmpty {
                VStack(spacing: 5) {
                    ForEach(task.subtasks) { subtask in
                        SubtaskRow(
                            subtask: subtask,
                            completed: subtask.isCompleted(on: model.selectedDate, calendar: .french),
                            palette: palette,
                            action: {
                                model.toggleSubtask(taskID: task.id, subtaskID: subtask.id)
                            }
                        )
                    }
                }
                .padding(.leading, 42)
                .padding(.trailing, 9)
                .padding(.bottom, 7)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    isDueNow
                        ? Color.orange.opacity(isHovering ? 0.84 : 0.72)
                        : palette.elevated.opacity(isHovering ? 0.72 : 0.52)
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    isDueNow ? Color.orange.opacity(0.95) : palette.secondary.opacity(0.09),
                    lineWidth: isDueNow ? 1.25 : 1
                )
                .allowsHitTesting(false)
        }
        .animation(.easeOut(duration: 0.18), value: isDueNow)
        .onHover { isHovering = $0 }
        .contextMenu {
            Button("Modifier") { model.openEditor(for: task) }
            if !task.subtasks.isEmpty {
                Button(isExpanded ? "Masquer les sous-tâches" : "Afficher les sous-tâches") {
                    onToggleExpansion()
                }
            }
            Divider()
            Button("Supprimer", role: .destructive) { model.delete(task) }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        var label = "\(task.title), \(isCompleted ? "terminée" : "non terminée")"
        if isDueNow {
            label += ", arrive à échéance maintenant"
        }
        if !task.subtasks.isEmpty {
            let completed = task.subtasks.filter {
                $0.isCompleted(on: model.selectedDate, calendar: .french)
            }.count
            label += ", \(completed) sous-tâche\(completed > 1 ? "s" : "") sur \(task.subtasks.count)"
        }
        return label
    }

    private func timeLabel(_ minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }
}

private struct TaskHoverActionButton: View {
    let icon: String
    let fill: Color
    var border: Color = .clear
    var rotation: Double = 0
    let help: String
    var disabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 9.5, weight: .bold))
                .foregroundStyle(Color.white)
                .rotationEffect(.degrees(rotation))
                .frame(width: 22, height: 22)
                .background(Circle().fill(fill))
                .overlay {
                    Circle()
                        .strokeBorder(border, lineWidth: 1)
                        .allowsHitTesting(false)
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .help(help)
        .accessibilityLabel(help)
    }
}

struct CompletionButton: View {
    let completed: Bool
    let partialProgress: Double
    let palette: StonePalette
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .stroke(completed ? palette.accent : palette.secondary.opacity(0.42), lineWidth: 1.5)
                if partialProgress > 0 && !completed {
                    Circle()
                        .trim(from: 0, to: partialProgress)
                        .stroke(palette.accent, style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                if completed {
                    Circle().fill(palette.accent)
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.white)
                }
            }
            .frame(width: 20, height: 20)
            .frame(width: 34, height: 34, alignment: .top)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(completed ? "Marquer comme non terminée" : "Marquer comme terminée")
        .accessibilityLabel(completed ? "Marquer comme non terminée" : "Marquer comme terminée")
    }
}

struct TaskBadge: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        Label(text, systemImage: icon)
            .font(.system(size: 10.5, weight: .medium))
            .foregroundStyle(color)
            .labelStyle(.titleAndIcon)
    }
}

struct SubtaskRow: View {
    let subtask: TodoSubtask
    let completed: Bool
    let palette: StonePalette
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: completed ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(completed ? palette.accent : palette.secondary.opacity(0.55))
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 3) {
                    Text(subtask.title)
                        .font(.system(size: 12.5))
                        .foregroundStyle(completed ? palette.secondary : palette.text)
                        .strikethrough(completed)
                    if let description = normalizedDescription {
                        Text(description)
                            .font(.system(size: 11))
                            .foregroundStyle(palette.secondary.opacity(completed ? 0.65 : 0.9))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer()
            }
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("subtask-checkbox-\(subtask.id.uuidString)")
        .accessibilityLabel(accessibilityLabel)
    }

    private var normalizedDescription: String? {
        let value = subtask.description?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? nil : value
    }

    private var accessibilityLabel: String {
        var label = completed
            ? "Marquer \(subtask.title) comme non terminée"
            : "Marquer \(subtask.title) comme terminée"
        if let normalizedDescription {
            label += ", \(normalizedDescription)"
        }
        return label
    }
}

struct QuickAddView: View {
    @EnvironmentObject private var model: AppModel
    let palette: StonePalette
    @State private var title = ""

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: model.postItModeEnabled ? "note.text" : "plus")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(model.postItModeEnabled ? model.postItMode.color : palette.accent)
            TextField(entryPlaceholder, text: $title)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
                .foregroundStyle(palette.text)
                .onSubmit(add)
            Button(model.postItModeEnabled ? "Coller" : "Ajouter") { add() }
                .buttonStyle(.borderedProminent)
                .tint(model.postItModeEnabled ? model.postItMode.color : palette.accent)
                .controlSize(.small)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button {
                if model.postItModeEnabled {
                    model.openPostItBoard()
                } else {
                    model.openNewTask()
                }
            } label: {
                Image(systemName: model.postItModeEnabled ? "rectangle.stack" : "slider.horizontal.3")
                    .frame(width: 25, height: 25)
            }
            .buttonStyle(.plain)
            .foregroundStyle(palette.secondary)
            .help(model.postItModeEnabled ? "Voir les post-it \(model.postItMode.label)" : "Ajouter avec des détails")
        }
        .padding(.horizontal, 10)
        .frame(height: 42)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(palette.elevated.opacity(0.62))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(palette.secondary.opacity(0.12), lineWidth: 1)
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 8)
        .padding(.top, 4)
    }

    private func add() {
        model.addQuickEntry(title: title)
        title = ""
    }

    private var entryPlaceholder: String {
        switch model.postItMode {
        case .off: "Ajouter une tâche…"
        case .persistent: "Ajouter un post-it toujours visible…"
        case .daily: "Ajouter un post-it daily…"
        }
    }
}
