import SwiftUI

struct LLMComposerView: View {
    @EnvironmentObject private var model: AppModel
    let palette: StonePalette
    @FocusState private var promptFocused: Bool

    var body: some View {
        VStack(spacing: 7) {
            HStack(spacing: 7) {
                Image(systemName: "message.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(palette.vein)

                Text("Assistant Quartz")
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.88))

                Text(model.llmConnectionStatus)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(model.llmEnabled ? .white.opacity(0.55) : .orange.opacity(0.9))

                Spacer()

                Button {
                    model.setLLMEnabled(!model.llmEnabled)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "power")
                        Text(model.llmEnabled ? "Active" : "Coupée")
                    }
                    .font(.system(size: 9.5, weight: .semibold))
                    .padding(.horizontal, 7)
                    .frame(height: 22)
                    .background(
                        Capsule().fill(
                            model.llmEnabled
                                ? palette.vein.opacity(0.24)
                                : Color.orange.opacity(0.16)
                        )
                    )
                    .overlay {
                        Capsule().strokeBorder(
                            model.llmEnabled
                                ? palette.vein.opacity(0.5)
                                : Color.orange.opacity(0.5)
                        )
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(model.llmEnabled ? palette.vein : Color.orange)
                .help(model.llmEnabled ? "Désactiver l’IA locale" : "Activer l’IA locale")
                .accessibilityLabel(model.llmEnabled ? "Désactiver l’IA locale" : "Activer l’IA locale")

                Button {
                    model.closeLLMComposer()
                } label: {
                    Image(systemName: "xmark")
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(ComposerPlainButtonStyle())
                .help("Fermer l’assistant")
            }

            HStack(spacing: 6) {
                TextField(
                    model.llmEnabled ? "Décris la tâche à créer…" : "L’IA locale est désactivée",
                    text: $model.llmDraft,
                    axis: .vertical
                )
                    .textFieldStyle(.plain)
                    .font(.system(size: 13.5))
                    .foregroundStyle(.white)
                    .tint(palette.vein)
                    .lineLimit(1...3)
                    .focused($promptFocused)
                    .onSubmit { model.prepareLLMSend() }
                    .disabled(!model.llmEnabled)

                HStack(spacing: 5) {
                    Image(systemName: model.postItModeEnabled ? "note.text" : "desktopcomputer")
                    Text(destinationLabel)
                }
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, 7)
                .frame(height: 28)
                .background(Capsule().fill(Color.white.opacity(0.10)))
                .fixedSize()
                .accessibilityLabel("LLM local")

                Button {
                    model.openLLMConnection()
                } label: {
                    Image(systemName: model.isLLMPreferenceSaved ? "link.circle.fill" : "link.badge.plus")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(ComposerPlainButtonStyle(accent: palette.vein))
                .help("Configurer la connexion")

                Button {
                    model.prepareLLMSend()
                } label: {
                    Group {
                        if model.isLLMSending {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 13, weight: .bold))
                        }
                    }
                    .foregroundStyle(Color.black.opacity(0.76))
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color.white.opacity(0.94)))
                }
                .buttonStyle(.plain)
                .disabled(
                    !model.llmEnabled
                        || model.llmDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || model.isLLMSending
                )
                .help("Interpréter puis vérifier la tâche")
                .accessibilityLabel("Envoyer au LLM")
                .accessibilityHint("Interprète la demande avec MLX puis ouvre la tâche pour confirmation")
            }

            if let error = model.llmErrorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(Color.orange.opacity(0.96))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background {
            ZStack {
                StoneFill(palette: palette)
                Color.black.opacity(model.theme.usesDarkAppearance ? 0.48 : 0.66)
                LinearGradient(
                    colors: [Color.white.opacity(0.08), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .shadow(color: Color.black.opacity(0.28), radius: 18, y: 8)
        .frame(maxWidth: 360)
        .onAppear { promptFocused = true }
    }

    private var destinationLabel: String {
        switch model.postItMode {
        case .off: "Tâche"
        case .persistent: "Toujours"
        case .daily: "Daily"
        }
    }
}

private struct ComposerPlainButtonStyle: ButtonStyle {
    var accent = Color.white

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundStyle(accent.opacity(configuration.isPressed ? 0.62 : 0.86))
            .background(Circle().fill(Color.white.opacity(configuration.isPressed ? 0.12 : 0.055)))
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
    }
}

struct LLMConnectionView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var endpoint = ""
    @State private var llmModel = ""
    @State private var savedConfirmation = false

    private var palette: StonePalette { model.theme.palette }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Connexion au LLM")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(palette.text)
                    Text("Relie Quartz à un petit modèle installé sur ce Mac.")
                        .font(.system(size: 11))
                        .foregroundStyle(palette.secondary)
                }
                Spacer()
                Button("Terminé") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .tint(palette.accent)
                    .controlSize(.small)
            }
            .padding(.horizontal, 18)
            .frame(height: 62)

            Divider().opacity(0.35)

            ScrollView {
                VStack(alignment: .leading, spacing: 17) {
                    connectionSection(title: "MOTEUR LOCAL") {
                        HStack(spacing: 11) {
                            Image(systemName: "desktopcomputer")
                                .foregroundStyle(palette.accent)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("LLM local")
                                    .font(.system(size: 13.5, weight: .semibold))
                                Text("Privé · fonctionne sur ce Mac")
                                    .font(.system(size: 10.5))
                                    .foregroundStyle(palette.secondary)
                            }
                        }
                        .foregroundStyle(palette.text)
                    }

                    connectionSection(title: "MÉTHODE DE CONNEXION") {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("MLX-LM sur ce Mac", systemImage: "server.rack")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(palette.text)

                            Text("MLX-LM utilise directement la puce Apple du Mac et fournit une adresse locale que Quartz peut appeler sans envoyer tes tâches sur Internet.")
                                .font(.system(size: 11.5))
                                .foregroundStyle(palette.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            Divider().opacity(0.26)

                            ConnectionTextField(
                                title: "Adresse de MLX-LM",
                                placeholder: "http://127.0.0.1:8080/v1",
                                text: $endpoint,
                                palette: palette
                            )
                            ConnectionTextField(
                                title: "Petit modèle installé",
                                placeholder: "default_model",
                                text: $llmModel,
                                palette: palette
                            )
                        }
                    }

                    HStack(alignment: .top, spacing: 9) {
                        Image(systemName: "lock.shield.fill")
                            .foregroundStyle(palette.accent)
                        Text("Aucune clé ni aucun compte n’est nécessaire : la connexion reste limitée à ce Mac.")
                            .font(.system(size: 10.8))
                            .foregroundStyle(palette.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack(spacing: 7) {
                        Image(systemName: "sparkles")
                        Text("Quartz démarre automatiquement ce modèle lors du premier envoi")
                    }
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(palette.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)

                    Button {
                        let configuration = LLMConnectionConfiguration(
                            endpoint: endpoint.trimmingCharacters(in: .whitespacesAndNewlines),
                            model: llmModel.trimmingCharacters(in: .whitespacesAndNewlines),
                            preferenceSaved: true
                        )
                        model.saveLLMConfiguration(configuration)
                        savedConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: savedConfirmation ? "checkmark.circle.fill" : "link")
                            Text(savedConfirmation ? "Préférence enregistrée" : "Enregistrer ce choix")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(palette.accent)
                }
                .padding(18)
            }
        }
        .frame(width: 384, height: 360)
        .background {
            ZStack {
                palette.surface
                StoneFill(palette: palette)
                    .opacity(0.11)
            }
        }
        .onAppear(perform: loadConfiguration)
    }

    private func connectionSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 10.5, weight: .bold))
                .tracking(0.7)
                .foregroundStyle(palette.secondary)
            VStack(alignment: .leading, spacing: 10) {
                content()
            }
            .padding(13)
            .background {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(palette.elevated.opacity(0.52))
            }
        }
    }

    private func loadConfiguration() {
        let configuration = model.llmConfiguration
        endpoint = configuration.endpoint
        llmModel = configuration.model
        savedConfirmation = configuration.preferenceSaved
    }
}

private struct ConnectionTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let palette: StonePalette

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(palette.secondary)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
                .foregroundStyle(palette.text)
                .padding(.horizontal, 10)
                .frame(height: 34)
                .background {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(palette.surface.opacity(0.82))
                        .overlay {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .strokeBorder(palette.secondary.opacity(0.16))
                        }
                }
        }
    }
}
