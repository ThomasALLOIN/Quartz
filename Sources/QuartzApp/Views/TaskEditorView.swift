import QuartzKit
import SwiftUI

struct TaskEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: TodoTask
    @State private var hasTime: Bool
    @State private var time: Date
    @State private var newSubtask = ""

    private let isEditing: Bool
    private let palette: StonePalette
    private let onSave: (TodoTask) -> Void
    private let onDelete: (TodoTask) -> Void
    private let calendar = Calendar.french

    init(
        task: TodoTask?,
        selectedDate: Date,
        palette: StonePalette,
        isNewProposal: Bool = false,
        onSave: @escaping (TodoTask) -> Void,
        onDelete: @escaping (TodoTask) -> Void
    ) {
        let base = task ?? TodoTask(title: "", startDate: selectedDate)
        let initialTime = base.dueMinutes.flatMap {
            Calendar.french.date(byAdding: .minute, value: $0, to: Calendar.french.startOfDay(for: base.startDate))
        } ?? Calendar.french.date(bySettingHour: 9, minute: 0, second: 0, of: selectedDate) ?? selectedDate

        _draft = State(initialValue: base)
        _hasTime = State(initialValue: base.dueMinutes != nil)
        _time = State(initialValue: initialTime)
        isEditing = task != nil && !isNewProposal
        self.palette = palette
        self.onSave = onSave
        self.onDelete = onDelete
    }

    var body: some View {
        VStack(spacing: 0) {
            editorHeader

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    identityCard
                    planningCard
                    stepsCard

                    if isEditing {
                        Button(role: .destructive) {
                            onDelete(draft)
                            dismiss()
                        } label: {
                            Label("Supprimer la tâche", systemImage: "trash")
                                .font(.system(size: 11.5, weight: .medium))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.red.opacity(0.82))
                        .padding(.leading, 4)
                    }
                }
                .padding(12)
            }
            .scrollIndicators(.never)
        }
        .frame(width: 384, height: 360)
        .background {
            ZStack {
                palette.surface
                StoneFill(palette: palette)
                    .opacity(0.07)
            }
        }
        .onChange(of: hasTime) { _, enabled in
            if !enabled { draft.reminder = .none }
        }
    }

    private var editorHeader: some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10.5, weight: .bold))
                    .frame(width: 27, height: 27)
                    .background(Circle().fill(palette.elevated.opacity(0.72)))
            }
            .buttonStyle(.plain)
            .foregroundStyle(palette.secondary)
            .help("Annuler")

            VStack(alignment: .leading, spacing: 1) {
                Text(isEditing ? "Modifier" : "Nouvelle tâche")
                    .font(.system(size: 14.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.text)
                Text("Une intention, quelques étapes")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(palette.secondary)
            }

            Spacer()

            Button(action: save) {
                Label("Enregistrer", systemImage: "checkmark")
                    .font(.system(size: 11.5, weight: .semibold))
            }
            .buttonStyle(.borderedProminent)
            .tint(palette.accent)
            .controlSize(.small)
            .disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 12)
        .frame(height: 48)
        .background {
            ZStack {
                StoneFill(palette: palette).opacity(0.13)
                palette.elevated.opacity(0.34)
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(palette.secondary.opacity(0.12))
                .frame(height: 1)
        }
    }

    private var identityCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top, spacing: 9) {
                Image(systemName: "diamond.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(palette.accent)
                    .padding(.top, 5)

                TextField("Que voulez-vous accomplir ?", text: $draft.title, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.text)
                    .lineLimit(1...3)
            }

            Rectangle()
                .fill(palette.secondary.opacity(0.12))
                .frame(height: 1)

            TextField("Ajouter une note…", text: $draft.notes, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(palette.secondary)
                .lineLimit(1...3)
                .padding(.leading, 18)
        }
        .padding(12)
        .background(editorCardBackground)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tâche et note")
    }

    private var planningCard: some View {
        EditorCard(title: "Planification", icon: "calendar", palette: palette) {
            EditorValueRow(icon: "calendar", title: "Date", palette: palette) {
                DatePicker("", selection: $draft.startDate, displayedComponents: .date)
                    .labelsHidden()
                    .environment(\.locale, Locale(identifier: "fr_FR"))
            }

            editorDivider

            EditorValueRow(icon: "clock", title: "Ajouter une heure", palette: palette) {
                Toggle("", isOn: $hasTime)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(palette.accent)
                    .controlSize(.small)
            }

            if hasTime {
                HStack {
                    Text("À")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(palette.secondary)
                    Spacer()
                    DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .environment(\.locale, Locale(identifier: "fr_FR"))
                }
                .padding(.leading, 26)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            editorDivider

            EditorValueRow(icon: "arrow.triangle.2.circlepath", title: "Répéter", palette: palette) {
                Picker("Récurrence", selection: $draft.recurrence) {
                    ForEach(RecurrenceRule.allCases) { recurrence in
                        Text(recurrence.label).tag(recurrence)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(maxWidth: 150)
            }

            editorDivider

            EditorValueRow(
                icon: "bell",
                title: "Rappel",
                palette: palette,
                enabled: hasTime
            ) {
                Picker("Rappel", selection: $draft.reminder) {
                    ForEach(ReminderOption.allCases) { reminder in
                        Text(reminder.label).tag(reminder)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(maxWidth: 150)
                .disabled(!hasTime)
            }

            if draft.recurrence != .none {
                Label("Toute la série sera mise à jour", systemImage: "info.circle")
                    .font(.system(size: 10.5))
                    .foregroundStyle(palette.secondary)
                    .padding(.leading, 26)
            }
        }
    }

    private var stepsCard: some View {
        EditorCard(title: "Étapes", icon: "checklist", palette: palette) {
            if draft.subtasks.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(palette.accent.opacity(0.8))
                    Text("Découpez la tâche seulement si cela vous aide.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(palette.secondary)
                }
                .padding(.vertical, 3)
            } else {
                ForEach($draft.subtasks) { subtask in
                    SubtaskEditorRow(subtask: subtask, palette: palette) {
                        let id = subtask.wrappedValue.id
                        withAnimation(.easeOut(duration: 0.14)) {
                            draft.subtasks.removeAll { $0.id == id }
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(palette.accent)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(palette.accent.opacity(0.12)))

                TextField("Nouvelle étape…", text: $newSubtask)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5, weight: .medium))
                    .onSubmit(addSubtask)

                Button(action: addSubtask) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(Color.white)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(palette.accent))
                }
                .buttonStyle(.plain)
                .disabled(newSubtask.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(newSubtask.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.38 : 1)
                .help("Ajouter l’étape")
            }
            .padding(.horizontal, 8)
            .frame(height: 38)
            .background {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(palette.surface.opacity(0.62))
            }
        } accessory: {
            if !draft.subtasks.isEmpty {
                Text("\(draft.subtasks.count)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.accent)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(palette.accent.opacity(0.12)))
            }
        }
    }

    private var editorDivider: some View {
        Rectangle()
            .fill(palette.secondary.opacity(0.1))
            .frame(height: 1)
            .padding(.leading, 26)
    }

    private var editorCardBackground: some View {
        RoundedRectangle(cornerRadius: 15, style: .continuous)
            .fill(palette.elevated.opacity(0.48))
            .overlay {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.045), lineWidth: 1)
            }
    }

    private func addSubtask() {
        let trimmed = newSubtask.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        withAnimation(.easeOut(duration: 0.16)) {
            draft.subtasks.append(TodoSubtask(title: trimmed))
        }
        newSubtask = ""
    }

    private func save() {
        draft.title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.subtasks = draft.subtasks.compactMap { subtask in
            var cleaned = subtask
            cleaned.title = cleaned.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.title.isEmpty else { return nil }

            let description = cleaned.description?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            cleaned.description = description.isEmpty ? nil : description
            return cleaned
        }

        if hasTime {
            let components = calendar.dateComponents([.hour, .minute], from: time)
            draft.dueMinutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        } else {
            draft.dueMinutes = nil
            draft.reminder = .none
        }
        onSave(draft)
        dismiss()
    }
}

private struct EditorCard<Content: View, Accessory: View>: View {
    let title: String
    let icon: String
    let palette: StonePalette
    @ViewBuilder let content: Content
    @ViewBuilder let accessory: Accessory

    init(
        title: String,
        icon: String,
        palette: StonePalette,
        @ViewBuilder content: () -> Content,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.title = title
        self.icon = icon
        self.palette = palette
        self.content = content()
        self.accessory = accessory()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(palette.accent)
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.text)
                Spacer()
                accessory
            }

            VStack(spacing: 9) {
                content
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(palette.elevated.opacity(0.43))
                .overlay {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.04), lineWidth: 1)
                }
        }
    }
}

private extension EditorCard where Accessory == EmptyView {
    init(
        title: String,
        icon: String,
        palette: StonePalette,
        @ViewBuilder content: () -> Content
    ) {
        self.init(title: title, icon: icon, palette: palette, content: content) {
            EmptyView()
        }
    }
}

private struct EditorValueRow<Value: View>: View {
    let icon: String
    let title: String
    let palette: StonePalette
    var enabled = true
    @ViewBuilder let value: Value

    init(
        icon: String,
        title: String,
        palette: StonePalette,
        enabled: Bool = true,
        @ViewBuilder value: () -> Value
    ) {
        self.icon = icon
        self.title = title
        self.palette = palette
        self.enabled = enabled
        self.value = value()
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(enabled ? palette.accent.opacity(0.88) : palette.secondary.opacity(0.4))
                .frame(width: 18)
            Text(title)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(enabled ? palette.text : palette.secondary.opacity(0.55))
            Spacer(minLength: 8)
            value
        }
    }
}

private struct SubtaskEditorRow: View {
    @Binding var subtask: TodoSubtask
    let palette: StonePalette
    let onDelete: () -> Void
    @State private var isHovering = false

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Circle()
                .stroke(palette.accent.opacity(0.62), lineWidth: 1.4)
                .frame(width: 17, height: 17)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                TextField("Nom de l’étape", text: $subtask.title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(palette.text)

                TextField("Ajouter un détail…", text: description, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11.2))
                    .foregroundStyle(palette.secondary)
                    .lineLimit(1...2)
            }

            Button(action: onDelete) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 8.5, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Color.red.opacity(0.78)))
            }
            .buttonStyle(.plain)
            .opacity(isHovering ? 1 : 0)
            .scaleEffect(isHovering ? 1 : 0.82)
            .allowsHitTesting(isHovering)
            .accessibilityHidden(!isHovering)
            .help("Supprimer cette étape")
        }
        .padding(9)
        .background {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(palette.surface.opacity(isHovering ? 0.72 : 0.5))
        }
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovering)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private var description: Binding<String> {
        Binding(
            get: { subtask.description ?? "" },
            set: { subtask.description = $0 }
        )
    }
}
