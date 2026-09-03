import SwiftUI

struct CompactStoneView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false
    @State private var dockSide = WindowCoordinator.shared.currentCompactDockSide

    private var palette: StonePalette { model.theme.palette }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let dueTasks = model.tasksDueNow(at: context.date)
            let additionalDueTasks = max(0, dueTasks.count - 1)
            ZStack {
            StoneFill(palette: palette, compact: true)
                .clipShape(DockedObeliskMassifShape(side: dockSide))

            ObeliskRelief(palette: palette)
                .scaleEffect(x: dockSide == .right ? -1 : 1, y: 1)
                .clipShape(DockedObeliskMassifShape(side: dockSide))

            DockEdgeSeal(palette: palette, side: dockSide)

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
                    additionalCount: additionalDueTasks
                )
                .offset(y: 7)
                .transition(.scale(scale: 0.82).combined(with: .opacity))
            }
        }
        .clipShape(DockedObeliskMassifShape(side: dockSide))
        .overlay {
            ZStack {
                WindowDragArea(
                    region: .obeliskMassif(side: dockSide),
                    onClick: { model.setCompact(false) },
                    onMove: { dockSide = WindowCoordinator.shared.rememberCompactOrigin($0) },
                    contextMenuItems: compactContextMenuItems
                )
                .accessibilityHidden(true)

                DockedObeliskMassifShape(side: dockSide)
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
            .clipShape(DockedObeliskMassifShape(side: dockSide))
        }
        .shadow(color: palette.shadow, radius: 3.5, y: 1.5)
        .contentShape(DockedObeliskMassifShape(side: dockSide))
        .padding(1.5)
        .opacity(isHovered || !dueTasks.isEmpty ? 1 : 0.5)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.09), value: isHovered)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: dueTasks.map(\.id))
        .onHover { hovering in
            isHovered = hovering
        }
        .onAppear {
            dockSide = WindowCoordinator.shared.currentCompactDockSide
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            dueTasks.first.map { "Échéance maintenant, \($0.title)" }
                ?? "Quartz réduit, \(model.remainingCount) tâches restantes, \(model.dayProgressPercent) pour cent accomplis"
        )
        .accessibilityHint("Ancré à gauche ou à droite selon sa position. Cliquer pour déplier Quartz vers l’intérieur, ou faire glisser la pierre vers l’autre bord.")
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

/// Le massif se retourne avec son ancrage : ses plans et ses aiguilles semblent
/// ainsi provenir du bord de l’écran, au lieu d’être un même objet posé à gauche
/// comme à droite.
private struct DockedObeliskMassifShape: Shape {
    let side: WindowCoordinator.CompactDockSide

    func path(in rect: CGRect) -> Path {
        var path = Path(ObeliskMassifGeometry.path(in: rect))
        guard side == .right else { return path }
        path = path.applying(
            CGAffineTransform(translationX: rect.midX * 2, y: 0).scaledBy(x: -1, y: 1)
        )
        return path
    }
}

/// Fine cicatrice minérale au contact du bord et chevron très discret vers la
/// zone où Quartz va se déployer. Il ne remplace ni le clic ni la silhouette.
private struct DockEdgeSeal: View {
    let palette: StonePalette
    let side: WindowCoordinator.CompactDockSide

    var body: some View {
        HStack(spacing: 3) {
            Capsule()
                .fill(palette.vein.opacity(0.62))
                .frame(width: 1.15, height: 17)
                .shadow(color: Color.black.opacity(0.42), radius: 0.8, x: 0.45)
            Image(systemName: side == .left ? "chevron.right" : "chevron.left")
                .font(.system(size: 5, weight: .bold))
                .foregroundStyle(palette.text.opacity(0.72))
        }
        .frame(width: 14, height: 21)
        .offset(x: side == .left ? -26 : 26, y: 5)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
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
