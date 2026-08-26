import QuartzKit
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Group {
            if model.isCompact {
                CompactStoneView()
            } else {
                ExpandedView()
            }
        }
        .frame(
            minWidth: model.isCompact
                ? WindowCoordinator.compactSize.width
                : WindowCoordinator.expandedMinSize.width,
            idealWidth: model.isCompact
                ? WindowCoordinator.compactSize.width
                : WindowCoordinator.expandedDefaultSize.width,
            maxWidth: model.isCompact ? WindowCoordinator.compactSize.width : .infinity,
            minHeight: model.isCompact
                ? WindowCoordinator.compactSize.height
                : WindowCoordinator.expandedMinSize.height,
            idealHeight: model.isCompact
                ? WindowCoordinator.compactSize.height
                : WindowCoordinator.expandedDefaultSize.height,
            maxHeight: model.isCompact ? WindowCoordinator.compactSize.height : .infinity
        )
        .background {
            ZStack {
                WindowReader(
                    compact: model.isCompact,
                    alwaysOnTop: model.alwaysOnTop,
                    visible: model.isWidgetVisible
                )
                PostItPanelReader(
                    model: model,
                    visible: model.postItShelfVisible
                        && !model.isCompact
                        && model.isWidgetVisible
                )
            }
            .allowsHitTesting(false)
        }
        .environment(\.colorScheme, model.theme.usesDarkAppearance ? .dark : .light)
        .onAppear { model.preparePostItLayout() }
        .sheet(item: $model.editorRequest) { request in
            TaskEditorView(
                task: model.task(for: request),
                selectedDate: model.selectedDate,
                palette: model.theme.palette,
                isNewProposal: request.proposedTask != nil,
                onSave: model.save,
                onDelete: model.delete
            )
            .environment(\.colorScheme, model.theme.usesDarkAppearance ? .dark : .light)
        }
        .sheet(isPresented: $model.settingsPresented) {
            SettingsView()
                .environmentObject(model)
                .environment(\.colorScheme, model.theme.usesDarkAppearance ? .dark : .light)
        }
        .sheet(isPresented: $model.llmConnectionPresented) {
            LLMConnectionView()
                .environmentObject(model)
                .environment(\.colorScheme, model.theme.usesDarkAppearance ? .dark : .light)
        }
        .alert(item: $model.storageNotice) { notice in
            Alert(
                title: Text(notice.title),
                message: Text(notice.message),
                primaryButton: .default(Text("Afficher les données")) {
                    model.revealDataFolder()
                },
                secondaryButton: .cancel(Text("Fermer"))
            )
        }
    }
}

struct ExpandedView: View {
    @EnvironmentObject private var model: AppModel

    private var palette: StonePalette { model.theme.palette }

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(palette.backdrop)
            StoneFill(palette: palette)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))

            VStack(spacing: 0) {
                AppHeaderView(palette: palette)
                WeekStripView(palette: palette)
                DailyProgressView(palette: palette)
                    .padding(.horizontal, 10)
                    .padding(.top, 5)
                    .padding(.bottom, 5)

                Rectangle()
                    .fill(palette.secondary.opacity(0.12))
                    .frame(height: 1)
                    .padding(.horizontal, 10)

                TaskListView(palette: palette)
                QuickAddView(palette: palette)
            }
            .background(palette.surface.opacity(model.theme.usesDarkAppearance ? 0.88 : 0.84))
            .clipShape(RoundedRectangle(cornerRadius: 21, style: .continuous))
            .padding(5)

            if model.llmComposerPresented {
                LLMComposerView(palette: palette)
                    .environmentObject(model)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(3)
            }

        }
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color.white.opacity(0.42), lineWidth: 1)
        }
        .ignoresSafeArea(.container, edges: .top)
        .animation(.easeOut(duration: 0.16), value: model.llmComposerPresented)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Quartz, tâches du jour")
    }
}

struct AppHeaderView: View {
    @EnvironmentObject private var model: AppModel
    let palette: StonePalette
    @State private var showMonth = false

    var body: some View {
        HStack(spacing: 6) {
            HStack(spacing: 5) {
                QuartzObelisksShape()
                    .fill(palette.text, style: FillStyle(eoFill: true))
                    .frame(width: 18, height: 18)
                    .accessibilityHidden(true)
                Text("Quartz")
                    .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(model.postItModeEnabled ? model.postItMode.color : palette.text)
                    .frame(height: 34, alignment: .leading)
                    .contentShape(Rectangle())
                    .onHover { model.setPostItTriggerHovered($0) }
                    .help(model.postItModeEnabled ? "Survoler pour afficher les post-it \(model.postItMode.label)" : "Quartz")
            }
            .foregroundStyle(palette.text)
            .frame(width: 72, alignment: .leading)

            HStack(spacing: 2) {
                Button {
                    model.moveDay(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .help("Jour précédent")
                .buttonStyle(HeaderIconButtonStyle(palette: palette))

                Button {
                    showMonth.toggle()
                } label: {
                    VStack(spacing: 0) {
                        Text(dayTitle(model.selectedDate))
                            .font(.system(size: 11.5, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text(monthTitle(model.selectedDate))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(palette.secondary)
                            .lineLimit(1)
                    }
                    .frame(width: 76)
                }
                .buttonStyle(.plain)
                .foregroundStyle(palette.text)
                .popover(isPresented: $showMonth, arrowEdge: .top) {
                    MonthCalendarView(palette: palette, isPresented: $showMonth)
                        .environmentObject(model)
                }
                .help("Ouvrir le mois")

                Button {
                    model.moveDay(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .help("Jour suivant")
                .buttonStyle(HeaderIconButtonStyle(palette: palette))
            }

            Spacer(minLength: 0)

            HStack(spacing: 2) {
                Button {
                    model.togglePostItMode()
                } label: {
                    Image(systemName: model.postItModeEnabled ? "note.text" : "note.text.badge.plus")
                }
                .help(model.postItMode.nextActionHelp)
                .buttonStyle(
                    HeaderIconButtonStyle(
                        palette: palette,
                        isActive: model.postItModeEnabled,
                        activeColor: model.postItMode.color
                    )
                )

                Button {
                    model.toggleLLMComposer()
                } label: {
                    Image(systemName: model.llmComposerPresented ? "message.fill" : "message")
                        .opacity(model.llmEnabled ? 1 : 0.48)
                }
                .help(
                    model.llmComposerPresented
                        ? "Fermer l’assistant"
                        : (model.llmEnabled ? "Ouvrir l’assistant" : "Assistant désactivé — ouvrir")
                )
                .buttonStyle(HeaderIconButtonStyle(palette: palette))

                Button {
                    model.setCompact(true)
                } label: {
                    Image(systemName: "diamond.bottomhalf.filled")
                }
                .help("Réduire en pierre")
                .buttonStyle(HeaderIconButtonStyle(palette: palette))

                Button {
                    model.openSettings()
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .help("Réglages")
                .buttonStyle(HeaderIconButtonStyle(palette: palette))

            }
        }
        .padding(.horizontal, 10)
        .frame(height: 44)
        .background(WindowDragArea())
        .background {
            ZStack {
                StoneFill(palette: palette)
                    .opacity(0.22)
                palette.elevated.opacity(0.38)
            }
        }
    }

    private func dayTitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "EEEE d"
        return formatter.string(from: date).capitalized
    }

    private func monthTitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date).capitalized
    }
}

struct HeaderIconButtonStyle: ButtonStyle {
    let palette: StonePalette
    var isActive = false
    var activeColor: Color? = nil

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(isActive ? Color.white : palette.text)
            .frame(width: 26, height: 26)
            .background(
                Circle().fill(
                    isActive
                        ? (activeColor ?? palette.accent).opacity(configuration.isPressed ? 0.72 : 0.92)
                        : palette.elevated.opacity(configuration.isPressed ? 0.82 : 0.52)
                )
            )
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
    }
}

struct WeekStripView: View {
    @EnvironmentObject private var model: AppModel
    let palette: StonePalette
    private let calendar = Calendar.french

    var body: some View {
        HStack(spacing: 8) {
            ForEach(weekDates, id: \.self) { date in
                let selected = calendar.isDate(date, inSameDayAs: model.selectedDate)
                Button {
                    model.select(date)
                } label: {
                    VStack(spacing: 2) {
                        Text(weekday(date))
                            .font(.system(size: 8.5, weight: .semibold))
                            .textCase(.uppercase)
                        Text("\(calendar.component(.day, from: date))")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                        ZStack {
                            Circle()
                                .fill(calendar.isDateInToday(date) ? palette.vein : Color.clear)
                                .frame(width: 4, height: 4)
                            let notes = model.postIts(on: date)
                            if !notes.isEmpty {
                                HStack(spacing: 1.5) {
                                    ForEach(Array(notes.prefix(4))) { note in
                                        Capsule()
                                            .fill(note.tone.paperColor)
                                            .frame(width: 5, height: 2.5)
                                    }
                                }
                            }
                        }
                        .frame(height: 4)
                    }
                    .foregroundStyle(selected ? Color.white : palette.text)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(selected ? palette.accent : palette.elevated.opacity(0.28))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .strokeBorder(
                                Color.white.opacity(selected ? 0.38 : 0.16),
                                lineWidth: 0.75
                            )
                            .allowsHitTesting(false)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(accessibilityDate(date))
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
    }

    private var weekDates: [Date] {
        let selected = calendar.startOfDay(for: model.selectedDate)
        let weekday = calendar.component(.weekday, from: selected)
        let offset = (weekday - calendar.firstWeekday + 7) % 7
        guard let start = calendar.date(byAdding: .day, value: -offset, to: selected) else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    private func weekday(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "EEEEE"
        return formatter.string(from: date)
    }

    private func accessibilityDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateStyle = .full
        return formatter.string(from: date)
    }
}

struct DailyProgressView: View {
    @EnvironmentObject private var model: AppModel
    let palette: StonePalette

    var body: some View {
        VStack(spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Votre journée")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(palette.text)
                    Text(model.progressDescription)
                        .font(.system(size: 9.5, weight: .medium))
                        .lineLimit(1)
                        .foregroundStyle(palette.secondary)
                }
                Spacer()
                Text("\(model.dayProgressPercent) %")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.accent)
                    .monospacedDigit()
            }

            ProgressView(value: model.dayProgress)
                .progressViewStyle(.linear)
                .tint(palette.accent)
                .scaleEffect(x: 1, y: 1.35)
                .accessibilityLabel("Progression de la journée")
                .accessibilityValue("\(model.dayProgressPercent) pour cent")
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(palette.elevated.opacity(0.56))
        }
        .overlay(alignment: .topTrailing) {
            if model.dayProgress >= 1 {
                Image(systemName: "sparkle")
                    .foregroundStyle(palette.vein)
                    .padding(10)
                    .accessibilityHidden(true)
            }
        }
    }
}
