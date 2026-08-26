import AppKit
import SwiftUI

@MainActor
private final class QuartzPostItPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
private struct PostItPanelRoot: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        PostItBoardView()
            .environment(\.colorScheme, model.theme.usesDarkAppearance ? .dark : .light)
            .padding(.leading, 8)
            .padding(.vertical, 8)
            .background(Color.clear)
    }
}

/// Maintient le mur de notes dans un panneau latéral lié à la fenêtre Todo.
/// Le panneau est au plus deux fois moins large et ne dépasse jamais sa hauteur.
@MainActor
struct PostItPanelReader: NSViewRepresentable {
    @ObservedObject var model: AppModel
    let visible: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(model: model)
    }

    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let parentWindow = nsView.window else { return }
            context.coordinator.update(parentWindow: parentWindow, visible: visible)
        }
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.tearDown()
    }

    @MainActor
    final class Coordinator: NSObject {
        private let model: AppModel
        private weak var parentWindow: NSWindow?
        private var panel: QuartzPostItPanel?
        private var observers: [NSObjectProtocol] = []

        init(model: AppModel) {
            self.model = model
        }

        func update(parentWindow: NSWindow, visible: Bool) {
            if self.parentWindow !== parentWindow {
                observe(parentWindow)
            }

            guard visible else {
                hide()
                return
            }

            let panel = panel ?? makePanel()
            self.panel = panel
            position(panel, beside: parentWindow)

            if panel.parent !== parentWindow {
                panel.parent?.removeChildWindow(panel)
                parentWindow.addChildWindow(panel, ordered: .above)
            }
            panel.level = parentWindow.level
            panel.orderFront(nil)
        }

        func tearDown() {
            observers.forEach(NotificationCenter.default.removeObserver)
            observers.removeAll()
            if let panel {
                panel.parent?.removeChildWindow(panel)
                panel.orderOut(nil)
                panel.close()
            }
            panel = nil
            parentWindow = nil
        }

        private func makePanel() -> QuartzPostItPanel {
            let panel = QuartzPostItPanel(
                contentRect: .zero,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            panel.title = "Post-it de Quartz"
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.isMovable = false
            panel.hidesOnDeactivate = false
            panel.isReleasedWhenClosed = false
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.contentView = NSHostingView(
                rootView: PostItPanelRoot().environmentObject(model)
            )
            return panel
        }

        private func observe(_ window: NSWindow) {
            observers.forEach(NotificationCenter.default.removeObserver)
            observers.removeAll()
            parentWindow = window

            let center = NotificationCenter.default
            for name in [NSWindow.didMoveNotification, NSWindow.didResizeNotification] {
                observers.append(
                    center.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                        MainActor.assumeIsolated {
                            guard let self, let panel = self.panel, panel.isVisible else { return }
                            self.position(panel, beside: window)
                        }
                    }
                )
            }
        }

        private func position(_ panel: NSPanel, beside parent: NSWindow) {
            let parentFrame = parent.frame
            let screenFrame = parent.screen?.visibleFrame ?? NSScreen.main?.visibleFrame
            let availableLeft = screenFrame.map { parentFrame.minX - $0.minX } ?? 300
            // Réduire le panneau est préférable à déplacer soudainement Quartz :
            // le texte resterait sinon hors du pointeur et le survol se couperait.
            let width = min(300, parentFrame.width / 2, max(160, availableLeft))
            let height = parentFrame.height

            let frame = NSRect(
                x: max(screenFrame?.minX ?? -CGFloat.greatestFiniteMagnitude, parentFrame.minX - width),
                y: parentFrame.maxY - height,
                width: width,
                height: height
            )
            panel.setFrame(frame, display: true)
        }

        private func hide() {
            guard let panel else { return }
            panel.parent?.removeChildWindow(panel)
            panel.orderOut(nil)
        }
    }
}
