import SwiftUI

struct CompactStoneView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    private var palette: StonePalette { model.theme.palette }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let dueTasks = model.tasksDueNow(at: context.date)
            ZStack {
            StoneFill(palette: palette, compact: true)
                .clipShape(ObeliskMassifShape())

            ObeliskRelief(palette: palette)
                .clipShape(ObeliskMassifShape())

            SecretCleftMark(palette: palette)
                .frame(width: 4, height: 12.5)
                .offset(y: -10.5)
                .allowsHitTesting(false)

            VStack(spacing: 2.5) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(model.dayProgress >= 1 ? "Fait" : "\(model.remainingCount)")
                        .font(.system(size: model.dayProgress >= 1 ? 10 : 12, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text(model.dayProgress >= 1 ? "aujourd’hui" : "à faire")
                        .font(.system(size: 5.5, weight: .semibold, design: .rounded))
                    if model.hasOverdueTask {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 2.5, height: 2.5)
                            .accessibilityLabel("Une tâche est en retard")
                    }
                }
                .foregroundStyle(palette.text)

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(palette.text.opacity(0.18))
                        Capsule()
                            .fill(palette.vein)
                            .frame(width: model.dayProgress == 0 ? 0 : max(1.5, proxy.size.width * model.dayProgress))
                    }
                }
                .frame(width: 29, height: 1.5)
            }
            .frame(width: 50, height: 29)
            .offset(y: 4.5)
            .shadow(color: palette.surface.opacity(0.92), radius: 0.6)
            .allowsHitTesting(false)

            if let currentTask = dueTasks.first {
                CompactDueTaskPill(
                    title: currentTask.title,
                    additionalCount: max(0, dueTasks.count - 1)
                )
                .offset(y: 7)
                .transition(.scale(scale: 0.82).combined(with: .opacity))
            }
        }
        .clipShape(ObeliskMassifShape())
        .overlay {
            ZStack {
                WindowDragArea(
                    region: .obeliskMassif,
                    onClick: { model.setCompact(false) },
                    onMove: { WindowCoordinator.shared.rememberCompactOrigin($0) },
                    contextMenuItems: compactContextMenuItems
                )
                .accessibilityHidden(true)

                ObeliskMassifShape()
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.54), palette.stoneDark.opacity(0.46)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 0.55, lineJoin: .round)
                    )
                    .allowsHitTesting(false)
            }
            .clipShape(ObeliskMassifShape())
        }
        .shadow(color: palette.shadow, radius: 3.5, y: 1.5)
        .contentShape(ObeliskMassifShape())
        .padding(1.5)
        .opacity(isHovered || !dueTasks.isEmpty ? 1 : 0.5)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.09), value: isHovered)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: dueTasks.map(\.id))
        .onHover { hovering in
            isHovered = hovering
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            dueTasks.first.map { "Échéance maintenant, \($0.title)" }
                ?? "Quartz réduit, \(model.remainingCount) tâches restantes, \(model.dayProgressPercent) pour cent accomplis"
        )
        .accessibilityHint("Cliquer pour déplier Quartz, ou faire glisser la pierre pour la déplacer")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            model.setCompact(false)
        }
        }
    }

    private var compactContextMenuItems: [WindowDragArea.ContextMenuItem] {
        [
            .action(title: "Déplier") {
                model.setCompact(false)
            },
            .action(title: "Nouvelle tâche") {
                model.setCompact(false)
                model.openNewTask()
            },
            .action(title: "Aujourd’hui") {
                model.goToToday()
            },
            .separator,
            .action(
                title: model.notificationsEnabled
                    ? "Désactiver les notifications"
                    : "Activer les notifications"
            ) {
                model.setNotificationsEnabled(!model.notificationsEnabled)
            },
            .action(
                title: model.soundsEnabled
                    ? "Désactiver les sons"
                    : "Activer les sons"
            ) {
                model.setSoundsEnabled(!model.soundsEnabled)
            },
            .submenu(
                title: "Pierre",
                items: StoneTheme.allCases.map { theme in
                    .action(title: theme.name, checked: theme == model.theme) {
                        model.setTheme(theme)
                    }
                }
            ),
            .separator,
            .action(title: "Quitter Quartz") {
                NSApp.terminate(nil)
            }
        ]
    }

}

private struct CompactDueTaskPill: View {
    let title: String
    let additionalCount: Int

    var body: some View {
        HStack(spacing: 2) {
            Circle()
                .fill(Color.white)
                .frame(width: 3, height: 3)
            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
            if additionalCount > 0 {
                Text("+\(additionalCount)")
                    .fontWeight(.bold)
            }
        }
        .font(.system(size: 6.7, weight: .semibold, design: .rounded))
        .foregroundStyle(Color.white)
        .padding(.horizontal, 5)
        .frame(width: 62, height: 13)
        .background(Capsule().fill(Color.orange.opacity(0.96)))
        .overlay {
            Capsule().strokeBorder(Color.white.opacity(0.55), lineWidth: 0.45)
        }
        .shadow(color: Color.black.opacity(0.32), radius: 1.5, y: 0.8)
        .allowsHitTesting(false)
    }
}

private struct SecretCleftMark: View {
    let palette: StonePalette

    var body: some View {
        ZStack {
            UnevenRoundedRectangle(
                topLeadingRadius: 4,
                bottomLeadingRadius: 1,
                bottomTrailingRadius: 1,
                topTrailingRadius: 4
            )
            .fill(Color.black.opacity(0.52))

            Rectangle()
                .fill(palette.vein.opacity(0.30))
                .frame(width: 0.5)
                .padding(.vertical, 2)
        }
        .shadow(color: Color.black.opacity(0.42), radius: 1)
    }
}
