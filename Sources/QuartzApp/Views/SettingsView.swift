import AppKit
import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    private var palette: StonePalette { model.theme.palette }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Réglages")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(palette.text)
                Spacer()
                Button("Terminé") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .tint(palette.accent)
                    .controlSize(.small)
            }
            .padding(.horizontal, 14)
            .frame(height: 46)

            Divider().opacity(0.35)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    SettingsSection(title: "Comportement", palette: palette) {
                        SettingToggleRow(
                            icon: "pin.fill",
                            title: "Toujours visible",
                            detail: "Reste au-dessus des fenêtres et sur tous les bureaux.",
                            isOn: Binding(
                                get: { model.alwaysOnTop },
                                set: { model.setAlwaysOnTop($0) }
                            ),
                            palette: palette
                        )

                        Divider().opacity(0.28)

                        SettingToggleRow(
                            icon: "bell.fill",
                            title: "Notifications",
                            detail: model.notificationStatusLabel,
                            isOn: Binding(
                                get: { model.notificationsEnabled },
                                set: { model.setNotificationsEnabled($0) }
                            ),
                            palette: palette
                        )

                        if model.notificationStatus == .denied {
                            Button("Ouvrir Réglages Système") {
                                guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") else { return }
                                NSWorkspace.shared.open(url)
                            }
                            .buttonStyle(.link)
                            .font(.system(size: 11.5))
                        }

                        Divider().opacity(0.28)

                        SettingToggleRow(
                            icon: "speaker.wave.2.fill",
                            title: "Sons",
                            detail: "Un tintement discret lorsqu’une tâche est accomplie.",
                            isOn: Binding(
                                get: { model.soundsEnabled },
                                set: { model.setSoundsEnabled($0) }
                            ),
                            palette: palette
                        )
                    }

                    SettingsSection(title: "Assistant", palette: palette) {
                        SettingToggleRow(
                            icon: "cpu.fill",
                            title: "IA locale",
                            detail: model.llmRuntimeStatusLabel,
                            isOn: Binding(
                                get: { model.llmEnabled },
                                set: { model.setLLMEnabled($0) }
                            ),
                            palette: palette
                        )
                    }

                    SettingsSection(title: "Données", palette: palette) {
                        HStack(alignment: .top, spacing: 11) {
                            Image(systemName: "externaldrive.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(palette.accent)
                                .frame(width: 23, height: 23)
                                .background(Circle().fill(palette.accent.opacity(0.1)))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Sauvegarde locale")
                                    .font(.system(size: 13.5, weight: .medium))
                                    .foregroundStyle(palette.text)
                                Text("Quartz conserve automatiquement la dernière version valide et isole tout fichier illisible.")
                                    .font(.system(size: 10.8))
                                    .foregroundStyle(palette.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 8)
                            Button("Afficher") { model.revealDataFolder() }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        }
                    }

                    SettingsSection(title: "Style de pierre", palette: palette) {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(StoneTheme.allCases) { theme in
                                ThemeChoice(
                                    theme: theme,
                                    selected: theme == model.theme,
                                    action: { model.setTheme(theme) }
                                )
                            }
                        }
                    }

                    Text("Quartz conserve vos tâches uniquement sur ce Mac.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(palette.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
            }
        }
        .frame(width: 384, height: 360)
        .background(palette.surface)
        .task { await model.refreshNotificationStatus() }
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    let palette: StonePalette
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title.uppercased())
                .font(.system(size: 10.5, weight: .bold))
                .tracking(0.7)
                .foregroundStyle(palette.secondary)
            VStack(spacing: 12) {
                content
            }
            .padding(13)
            .background {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(palette.elevated.opacity(0.48))
            }
        }
    }
}

struct SettingToggleRow: View {
    let icon: String
    let title: String
    let detail: String
    @Binding var isOn: Bool
    let palette: StonePalette
    var enabled = true

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(palette.accent)
                .frame(width: 23, height: 23)
                .background(Circle().fill(palette.accent.opacity(0.1)))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(palette.text)
                Text(detail)
                    .font(.system(size: 10.8))
                    .foregroundStyle(palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(palette.accent)
                .controlSize(.small)
                .disabled(!enabled)
        }
        .opacity(enabled ? 1 : 0.68)
    }
}

struct ThemeChoice: View {
    let theme: StoneTheme
    let selected: Bool
    let action: () -> Void

    private var palette: StonePalette { theme.palette }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                ZStack {
                    StoneFill(palette: palette, compact: true)
                        .clipShape(StoneShape())
                }
                .frame(width: 38, height: 29)

                Text(theme.name)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(palette.text)
                    .lineLimit(1)
                Spacer(minLength: 2)
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(palette.accent)
                }
            }
            .padding(8)
            .background {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(palette.surface.opacity(0.7))
                    .overlay {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .strokeBorder(selected ? palette.accent : palette.secondary.opacity(0.1), lineWidth: selected ? 1.5 : 1)
                    }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(theme.name)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
