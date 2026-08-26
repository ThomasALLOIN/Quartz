import AppKit
import SwiftUI

@MainActor
final class WindowCoordinator {
    static let shared = WindowCoordinator()

    private enum PreferenceKey {
        static let compactOriginX = "quartz.window.compactOriginX"
        static let compactOriginY = "quartz.window.compactOriginY"
        static let expandedContentWidth = "quartz.window.expandedContentWidth"
        static let expandedContentHeight = "quartz.window.expandedContentHeight"
    }

    private enum LegacyPreferenceKey {
        static let compactOriginX = "ecrin.window.compactOriginX"
        static let compactOriginY = "ecrin.window.compactOriginY"
        static let expandedContentWidth = "ecrin.window.expandedContentWidth"
        static let expandedContentHeight = "ecrin.window.expandedContentHeight"
    }

    // Le mode déplié conserve 28 px de chrome masqué : son cadre réel varie
    // de 400 × 400 à 600 × 600. Le compact reste strictement fixe.
    // Le compact devient borderless : son cadre réel égale son contenu 74 × 42.
    static let expandedMinSize = NSSize(width: 400, height: 372)
    static let expandedMaxSize = NSSize(width: 600, height: 572)
    static let expandedDefaultSize = expandedMinSize
    static let expandedMinFrameSize = NSSize(width: 400, height: 400)
    static let expandedMaxFrameSize = NSSize(width: 600, height: 600)
    static let compactSize = NSSize(width: 74, height: 42)

    private var window: NSWindow?
    private var resizeGeneration = 0
    private var appliedCompactState: Bool?
    private var lastCompactOrigin: NSPoint?
    private var lastExpandedSize = expandedDefaultSize
    private var liveResizeObserver: NSObjectProtocol?
    private var resizeObserver: NSObjectProtocol?
    private var isEnforcingFrameRange = false
    private let preferences: UserDefaults
    var onVisibilityChange: ((Bool) -> Void)?

    private init(preferences: UserDefaults = .standard) {
        self.preferences = preferences
        Self.migrateLegacyPreferences(in: preferences)
        if
            let x = preferences.object(forKey: PreferenceKey.compactOriginX) as? NSNumber,
            let y = preferences.object(forKey: PreferenceKey.compactOriginY) as? NSNumber
        {
            lastCompactOrigin = NSPoint(x: x.doubleValue, y: y.doubleValue)
        }
        if
            let width = preferences.object(forKey: PreferenceKey.expandedContentWidth) as? NSNumber,
            let height = preferences.object(forKey: PreferenceKey.expandedContentHeight) as? NSNumber
        {
            lastExpandedSize = Self.clampedExpandedSize(
                NSSize(width: width.doubleValue, height: height.doubleValue)
            )
        }
    }

    private static func migrateLegacyPreferences(in preferences: UserDefaults) {
        let keys = [
            (PreferenceKey.compactOriginX, LegacyPreferenceKey.compactOriginX),
            (PreferenceKey.compactOriginY, LegacyPreferenceKey.compactOriginY),
            (PreferenceKey.expandedContentWidth, LegacyPreferenceKey.expandedContentWidth),
            (PreferenceKey.expandedContentHeight, LegacyPreferenceKey.expandedContentHeight)
        ]
        for (current, legacy) in keys {
            if preferences.object(forKey: current) == nil,
               let value = preferences.object(forKey: legacy)
            {
                preferences.set(value, forKey: current)
            }
            preferences.removeObject(forKey: legacy)
        }
    }

    var isWidgetVisible: Bool {
        guard let window else { return false }
        return window.isVisible && !window.isMiniaturized && !NSApp.isHidden
    }

    func attach(_ window: NSWindow, compact: Bool, alwaysOnTop: Bool, visible: Bool) {
        let firstAttachment = self.window !== window
        self.window = window

        // Le glisser est confié à des zones AppKit explicites. Cela évite que le
        // fond déplaçable de la fenêtre vole un clic aux boutons et checkboxes.
        window.isMovableByWindowBackground = false
        window.hidesOnDeactivate = false
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("QuartzMainWindow")

        applyAlwaysOnTop(alwaysOnTop)
        if firstAttachment {
            observeLiveResize(of: window)
            appliedCompactState = nil
            resize(compact: compact, animated: false)
        }
        if visible != isWidgetVisible {
            setVisible(visible)
        }
    }

    func resize(compact: Bool, animated: Bool = true) {
        resizeGeneration += 1
        let generation = resizeGeneration

        // Changer le theme-frame pendant le mouseUp d'un bouton peut invalider
        // sa hiérarchie AppKit. Le tour de boucle suivant garde le clic fiable.
        if animated {
            DispatchQueue.main.async { [weak self] in
                guard
                    let self,
                    self.resizeGeneration == generation,
                    let window = self.window
                else { return }
                self.performResize(
                    window: window,
                    compact: compact,
                    animated: true,
                    generation: generation
                )
            }
        } else {
            guard let window else { return }
            performResize(
                window: window,
                compact: compact,
                animated: false,
                generation: generation
            )
        }
    }

    private func performResize(
        window: NSWindow,
        compact: Bool,
        animated: Bool,
        generation: Int
    ) {
        let oldFrame = window.frame
        let wasCompact = appliedCompactState == true

        if compact, appliedCompactState == false {
            rememberExpandedSize(window.contentRect(forFrameRect: oldFrame).size)
        }
        let size = compact ? Self.compactSize : lastExpandedSize

        // Juste avant de déplier, la position réelle de la petite pierre est la
        // référence à restaurer au prochain repli. Une transition interrompue
        // n'écrase pas cette référence avec un cadre de taille intermédiaire.
        if !compact, wasCompact, isSettledCompactFrame(oldFrame) {
            rememberCompactOrigin(oldFrame.origin)
        }

        // Les anciennes contraintes fixes forceraient la destination avant que
        // l’animation ne commence. On les relâche seulement pendant la transition.
        window.minSize = NSSize(width: 1, height: 1)
        window.maxSize = NSSize(width: 10_000, height: 10_000)

        applyChrome(window: window, compact: compact)
        // La reconstruction du theme-frame peut modifier le cadre courant.
        // On restaure son ancre avant de calculer la destination.
        window.setFrame(oldFrame, display: false)

        var frame = NSWindow.frameRect(
            forContentRect: NSRect(origin: .zero, size: size),
            styleMask: window.styleMask
        )
        if compact, let lastCompactOrigin {
            frame.origin = lastCompactOrigin
        } else {
            // Au tout premier repli seulement, aucune position compacte n'existe
            // encore : le coin supérieur droit fournit un point de départ stable.
            frame.origin = NSPoint(x: oldFrame.maxX - frame.width, y: oldFrame.maxY - frame.height)
        }

        if let visible = visibleFrame(containing: frame, fallback: window) {
            frame.origin.x = min(max(frame.origin.x, visible.minX), visible.maxX - frame.width)
            frame.origin.y = min(max(frame.origin.y, visible.minY), visible.maxY - frame.height)
        }

        if compact {
            rememberCompactOrigin(frame.origin)
        }

        let shouldAnimate = animated && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if shouldAnimate {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.13
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                window.animator().setFrame(frame, display: true)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) { [weak self] in
                guard
                    let self,
                    self.resizeGeneration == generation,
                    let window = self.window
                else { return }
                self.applyContentSizeConstraints(to: window, compact: compact)
                window.invalidateShadow()
            }
        } else {
            window.setFrame(frame, display: true)
            applyContentSizeConstraints(to: window, compact: compact)
            window.invalidateShadow()
        }
    }

    private func applyContentSizeConstraints(to window: NSWindow, compact: Bool) {
        if compact {
            window.minSize = Self.compactSize
            window.maxSize = Self.compactSize
        } else {
            window.minSize = Self.expandedMinFrameSize
            window.maxSize = Self.expandedMaxFrameSize
        }
    }

    private func observeLiveResize(of window: NSWindow) {
        if let liveResizeObserver {
            NotificationCenter.default.removeObserver(liveResizeObserver)
        }
        if let resizeObserver {
            NotificationCenter.default.removeObserver(resizeObserver)
        }
        resizeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResizeNotification,
            object: window,
            queue: .main
        ) { [weak self, weak window] _ in
            MainActor.assumeIsolated {
                guard let self, let window else { return }
                self.enforceExpandedFrameRange(on: window)
            }
        }
        liveResizeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didEndLiveResizeNotification,
            object: window,
            queue: .main
        ) { [weak self, weak window] _ in
            MainActor.assumeIsolated {
                guard let self, let window, self.appliedCompactState == false else { return }
                self.rememberExpandedSize(window.contentRect(forFrameRect: window.frame).size)
            }
        }
    }

    private func enforceExpandedFrameRange(on window: NSWindow) {
        guard appliedCompactState == false, !isEnforcingFrameRange else { return }
        let oldFrame = window.frame
        let width = min(
            max(oldFrame.width, Self.expandedMinFrameSize.width),
            Self.expandedMaxFrameSize.width
        )
        let height = min(
            max(oldFrame.height, Self.expandedMinFrameSize.height),
            Self.expandedMaxFrameSize.height
        )
        guard abs(width - oldFrame.width) > 0.5 || abs(height - oldFrame.height) > 0.5 else { return }

        var frame = oldFrame
        frame.origin.y += oldFrame.height - height
        frame.size = NSSize(width: width, height: height)
        isEnforcingFrameRange = true
        window.setFrame(frame, display: true)
        isEnforcingFrameRange = false
    }

    private func rememberExpandedSize(_ size: NSSize) {
        let clamped = Self.clampedExpandedSize(size)
        lastExpandedSize = clamped
        preferences.set(Double(clamped.width), forKey: PreferenceKey.expandedContentWidth)
        preferences.set(Double(clamped.height), forKey: PreferenceKey.expandedContentHeight)
    }

    private static func clampedExpandedSize(_ size: NSSize) -> NSSize {
        NSSize(
            width: min(max(size.width, expandedMinSize.width), expandedMaxSize.width),
            height: min(max(size.height, expandedMinSize.height), expandedMaxSize.height)
        )
    }

    func rememberCompactOrigin(_ origin: NSPoint) {
        guard origin.x.isFinite, origin.y.isFinite else { return }
        lastCompactOrigin = origin
        preferences.set(Double(origin.x), forKey: PreferenceKey.compactOriginX)
        preferences.set(Double(origin.y), forKey: PreferenceKey.compactOriginY)
    }

    private func isSettledCompactFrame(_ frame: NSRect) -> Bool {
        abs(frame.width - Self.compactSize.width) < 1
            && abs(frame.height - Self.compactSize.height) < 1
    }

    private func visibleFrame(containing targetFrame: NSRect, fallback window: NSWindow) -> NSRect? {
        let targetCenter = NSPoint(x: targetFrame.midX, y: targetFrame.midY)
        let targetScreen = NSScreen.screens.first { $0.frame.contains(targetCenter) }
            ?? NSScreen.screens.first { $0.frame.intersects(targetFrame) }
        return targetScreen?.visibleFrame
            ?? window.screen?.visibleFrame
            ?? NSScreen.main?.visibleFrame
    }

    private func applyChrome(window: NSWindow, compact: Bool) {
        guard appliedCompactState != compact else { return }

        window.styleMask = compact
            ? [.borderless]
            : [.titled, .resizable, .fullSizeContentView]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.isMovableByWindowBackground = false
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        // L’ombre native suit toujours le cadre rectangulaire de NSWindow et
        // reste visible derrière nos coins arrondis. Quartz dessine son propre
        // contour : aucune ombre système ne doit révéler ce cadre transparent.
        window.hasShadow = false

        window.contentView?.wantsLayer = true
        window.contentView?.layer?.backgroundColor = NSColor.clear.cgColor

        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        appliedCompactState = compact
    }

    func applyAlwaysOnTop(_ enabled: Bool) {
        guard let window else { return }
        window.level = enabled ? .floating : .normal
        var behavior = window.collectionBehavior
        if enabled {
            behavior.insert(.canJoinAllSpaces)
            behavior.insert(.fullScreenAuxiliary)
        } else {
            behavior.remove(.canJoinAllSpaces)
            behavior.remove(.fullScreenAuxiliary)
        }
        window.collectionBehavior = behavior
    }

    func reserveLeftSpaceForPostIts() {
        guard
            appliedCompactState == false,
            let window,
            let visibleFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame
        else { return }

        let reservedWidth = min(300, window.frame.width / 2)
        let minimumX = visibleFrame.minX + reservedWidth
        let maximumX = visibleFrame.maxX - window.frame.width
        let targetX = min(max(window.frame.minX, minimumX), maximumX)
        guard abs(targetX - window.frame.minX) > 0.5 else { return }
        window.setFrameOrigin(NSPoint(x: targetX, y: window.frame.minY))
    }

    func setVisible(_ visible: Bool) {
        if visible {
            // Un menu NSStatusItem est encore en phase de fermeture lorsque son
            // action est appelée. Présenter au tour suivant évite que macOS ignore
            // le makeKeyAndOrderFront pendant le suivi du menu.
            DispatchQueue.main.async { [weak self] in
                NSApp.unhide(nil)
                NSApp.activate(ignoringOtherApps: true)
                self?.window?.makeKeyAndOrderFront(nil)
            }
        } else {
            window?.orderOut(nil)
        }
        onVisibilityChange?(visible)
    }

    func show() {
        setVisible(true)
    }
}

/// Une zone de glisser native qui évite toute compétition avec les contrôles
/// SwiftUI. L'en-tête utilise le glisser AppKit standard ; le petit massif suit
/// le pointeur explicitement afin de distinguer un clic d'une prise, même quand
/// Quartz n'était pas l'application active au premier mouseDown.
struct WindowDragArea: NSViewRepresentable {
    enum Region: Equatable {
        case rectangle
        case obeliskMassif
    }

    enum ContextMenuItem {
        case action(title: String, checked: Bool = false, handler: () -> Void)
        case submenu(title: String, items: [ContextMenuItem])
        case separator
    }

    var region: Region = .rectangle
    var onClick: (() -> Void)?
    var onMove: ((NSPoint) -> Void)?
    var contextMenuItems: [ContextMenuItem] = []

    func makeNSView(context: Context) -> NSView {
        NativeWindowDragView(
            region: region,
            onClick: onClick,
            onMove: onMove,
            contextMenuItems: contextMenuItems
        )
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let dragView = nsView as? NativeWindowDragView else { return }
        dragView.region = region
        dragView.onClick = onClick
        dragView.onMove = onMove
        dragView.contextMenuItems = contextMenuItems
    }

    private final class NativeWindowDragView: NSView {
        var region: Region
        var onClick: (() -> Void)?
        var onMove: ((NSPoint) -> Void)?
        var contextMenuItems: [ContextMenuItem]
        private var pointerOrigin: NSPoint?
        private var windowOrigin: NSPoint?
        private var didDrag = false
        private var contextActions: [String: () -> Void] = [:]

        init(
            region: Region,
            onClick: (() -> Void)?,
            onMove: ((NSPoint) -> Void)?,
            contextMenuItems: [ContextMenuItem]
        ) {
            self.region = region
            self.onClick = onClick
            self.onMove = onMove
            self.contextMenuItems = contextMenuItems
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) n'est pas pris en charge")
        }

        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        override func hitTest(_ point: NSPoint) -> NSView? {
            guard regionContains(point) else { return nil }
            return super.hitTest(point)
        }

        override func menu(for event: NSEvent) -> NSMenu? {
            guard !contextMenuItems.isEmpty else { return super.menu(for: event) }
            contextActions.removeAll(keepingCapacity: true)
            return buildMenu(from: contextMenuItems)
        }

        override func mouseDown(with event: NSEvent) {
            guard let window else {
                super.mouseDown(with: event)
                return
            }

            if event.modifierFlags.contains(.control), let menu = menu(for: event) {
                NSMenu.popUpContextMenu(menu, with: event, for: self)
                return
            }

            guard onClick != nil else {
                window.performDrag(with: event)
                return
            }

            pointerOrigin = NSEvent.mouseLocation
            windowOrigin = window.frame.origin
            didDrag = false
        }

        override func rightMouseDown(with event: NSEvent) {
            guard let menu = menu(for: event) else {
                super.rightMouseDown(with: event)
                return
            }
            NSMenu.popUpContextMenu(menu, with: event, for: self)
        }

        override func mouseDragged(with event: NSEvent) {
            guard
                let window,
                onClick != nil,
                let pointerOrigin,
                let windowOrigin
            else {
                super.mouseDragged(with: event)
                return
            }

            let pointer = NSEvent.mouseLocation
            let deltaX = pointer.x - pointerOrigin.x
            let deltaY = pointer.y - pointerOrigin.y
            if hypot(deltaX, deltaY) >= 2.5 {
                didDrag = true
            }

            guard didDrag else { return }
            window.setFrameOrigin(
                NSPoint(x: windowOrigin.x + deltaX, y: windowOrigin.y + deltaY)
            )
        }

        override func mouseUp(with event: NSEvent) {
            guard onClick != nil else {
                super.mouseUp(with: event)
                return
            }

            let movedOrigin = didDrag ? window?.frame.origin : nil
            let clickAction = didDrag ? nil : onClick
            pointerOrigin = nil
            windowOrigin = nil
            didDrag = false

            if let movedOrigin {
                onMove?(movedOrigin)
            }
            guard let clickAction else { return }
            DispatchQueue.main.async {
                clickAction()
            }
        }

        override func resetCursorRects() {
            addCursorRect(bounds, cursor: .openHand)
        }

        private func buildMenu(from items: [ContextMenuItem]) -> NSMenu {
            let menu = NSMenu()
            for entry in items {
                switch entry {
                case let .action(title, checked, handler):
                    let actionID = UUID().uuidString
                    contextActions[actionID] = handler
                    let item = NSMenuItem(
                        title: title,
                        action: #selector(runContextAction(_:)),
                        keyEquivalent: ""
                    )
                    item.target = self
                    item.representedObject = actionID
                    item.state = checked ? .on : .off
                    menu.addItem(item)

                case let .submenu(title, children):
                    let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
                    item.submenu = buildMenu(from: children)
                    menu.addItem(item)

                case .separator:
                    menu.addItem(.separator())
                }
            }
            return menu
        }

        @objc private func runContextAction(_ sender: NSMenuItem) {
            guard
                let actionID = sender.representedObject as? String,
                let action = contextActions[actionID]
            else { return }
            action()
        }

        private func regionContains(_ point: NSPoint) -> Bool {
            switch region {
            case .rectangle:
                return bounds.contains(point)
            case .obeliskMassif:
                // AppKit place l'origine en bas à gauche, tandis que la géométrie
                // SwiftUI du massif est décrite depuis le haut à gauche.
                let topDownPoint = CGPoint(x: point.x, y: bounds.height - point.y)
                return ObeliskMassifGeometry.path(in: bounds).contains(topDownPoint)
            }
        }
    }
}

struct WindowReader: NSViewRepresentable {
    let compact: Bool
    let alwaysOnTop: Bool
    let visible: Bool

    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            WindowCoordinator.shared.attach(
                window,
                compact: compact,
                alwaysOnTop: alwaysOnTop,
                visible: visible
            )
        }
    }
}
