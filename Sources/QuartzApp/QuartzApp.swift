import AppKit
import QuartzKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        WindowCoordinator.shared.setVisible(true)
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        LocalMLXRuntime.shared.stop()
    }
}

@main
struct QuartzApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("Quartz") {
            RootView()
                .environmentObject(model)
        }
        .defaultSize(
            width: WindowCoordinator.expandedDefaultSize.width,
            height: WindowCoordinator.expandedDefaultSize.height
        )
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button(
                    model.postItMode == .daily
                        ? "Nouveau post-it daily"
                        : (model.postItModeEnabled ? "Nouveau post-it toujours" : "Nouvelle tâche")
                ) {
                    model.openNewTask()
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            CommandGroup(replacing: .appSettings) {
                Button("Réglages…") {
                    model.openSettings()
                }
                .keyboardShortcut(",", modifiers: .command)
            }

            CommandMenu("Journée") {
                Button("Jour précédent") { model.moveDay(by: -1) }
                    .keyboardShortcut(.leftArrow, modifiers: .command)
                Button("Aujourd’hui") { model.goToToday() }
                    .keyboardShortcut("t", modifiers: [.command, .shift])
                Button("Jour suivant") { model.moveDay(by: 1) }
                    .keyboardShortcut(.rightArrow, modifiers: .command)
                Divider()
                Button(model.isCompact ? "Déplier" : "Réduire en pierre") {
                    model.setWidgetVisible(true)
                    model.setCompact(!model.isCompact)
                }
                .keyboardShortcut("m", modifiers: [.command, .shift])
            }

            CommandMenu("Widget") {
                Toggle(
                    "Afficher le widget",
                    isOn: Binding(
                        get: { model.isWidgetVisible },
                        set: { model.setWidgetVisible($0) }
                    )
                )
            }

            CommandMenu("Post-it") {
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
            }
        }

        MenuBarExtra {
            StatusMenuView()
                .environmentObject(model)
        } label: {
            QuartzMenuBarIcon()
        }
        .menuBarExtraStyle(.menu)
    }
}
