import AppKit
import QuartzKit
import SwiftUI

struct StatusMenuView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Group {
            Toggle(
                "Afficher le widget",
                isOn: Binding(
                    get: { model.isWidgetVisible },
                    set: { model.setWidgetVisible($0) }
                )
            )

            Divider()

            Button(model.isCompact ? "Déplier le widget" : "Réduire en pierre") {
                model.setWidgetVisible(true)
                model.setCompact(!model.isCompact)
            }

            Button(newItemLabel) {
                model.openNewTask()
            }
            .keyboardShortcut("n")

            Picker(
                "Mode post-it",
                selection: Binding(
                    get: { model.postItMode },
                    set: { model.setPostItMode($0) }
                )
            ) {
                ForEach(PostItMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }

            Button("Afficher les post-it") {
                model.openPostItBoard()
            }

            Button("Réglages…") {
                model.openSettings()
            }

            Divider()

            Button("Quitter Quartz") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .onAppear {
            model.synchronizeWidgetVisibility(WindowCoordinator.shared.isWidgetVisible)
        }
    }

    private var newItemLabel: String {
        switch model.postItMode {
        case .off: "Nouvelle tâche…"
        case .persistent: "Nouveau post-it toujours…"
        case .daily: "Nouveau post-it daily…"
        }
    }
}
