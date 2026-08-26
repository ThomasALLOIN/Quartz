import AppKit
import SwiftUI

/// Symbole monochrome de Quartz pour la barre des menus macOS.
///
/// Les trois aiguilles reprennent le sanctuaire du widget compact. La faille
/// centrale reste transparente afin que le pictogramme conserve son idée de
/// secret gardé dans les modes clair, sombre et avec les teintes d’accentuation.
struct QuartzMenuBarIcon: View {
    var body: some View {
        Image(nsImage: QuartzMenuBarArtwork.image)
            .renderingMode(.template)
            .resizable()
            .interpolation(.high)
            .frame(width: 18, height: 18)
            .accessibilityLabel("Quartz")
    }
}

/// Image AppKit « template » : macOS lui applique automatiquement la bonne
/// couleur dans la barre des menus, en clair comme en sombre.
@MainActor
enum QuartzMenuBarArtwork {
    static let image: NSImage = {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: true) { rect in
            let point: (CGFloat, CGFloat) -> NSPoint = { x, y in
                NSPoint(
                    x: rect.minX + rect.width * x / 18,
                    y: rect.minY + rect.height * y / 18
                )
            }
            let path = NSBezierPath()

            path.move(to: point(0.7, 18))
            path.line(to: point(1.8, 8.2))
            path.line(to: point(3.7, 5.8))
            path.line(to: point(5.1, 18))
            path.close()

            path.move(to: point(5.8, 18))
            path.line(to: point(7.3, 3.2))
            path.line(to: point(9.1, 0.5))
            path.line(to: point(11.1, 3.2))
            path.line(to: point(12.5, 18))
            path.close()

            path.move(to: point(13, 18))
            path.line(to: point(14.1, 8.1))
            path.line(to: point(16, 5.7))
            path.line(to: point(17.4, 18))
            path.close()

            path.move(to: point(9.1, 3.1))
            path.line(to: point(9.65, 4.3))
            path.line(to: point(9.65, 15.8))
            path.line(to: point(8.75, 15.8))
            path.line(to: point(8.75, 4.3))
            path.close()

            path.windingRule = .evenOdd
            NSColor.black.setFill()
            path.fill()
            return true
        }
        image.isTemplate = true
        return image
    }()
}

struct QuartzObelisksShape: Shape {
    func path(in rect: CGRect) -> Path {
        let point: (CGFloat, CGFloat) -> CGPoint = { x, y in
            CGPoint(
                x: rect.minX + rect.width * x / 18,
                y: rect.minY + rect.height * y / 18
            )
        }

        var path = Path()

        // Obélisque arrière gauche.
        path.move(to: point(0.7, 18))
        path.addLine(to: point(1.8, 8.2))
        path.addLine(to: point(3.7, 5.8))
        path.addLine(to: point(5.1, 18))
        path.closeSubpath()

        // Pierre centrale, plus haute et protectrice.
        path.move(to: point(5.8, 18))
        path.addLine(to: point(7.3, 3.2))
        path.addLine(to: point(9.1, 0.5))
        path.addLine(to: point(11.1, 3.2))
        path.addLine(to: point(12.5, 18))
        path.closeSubpath()

        // Obélisque arrière droit.
        path.move(to: point(13, 18))
        path.addLine(to: point(14.1, 8.1))
        path.addLine(to: point(16, 5.7))
        path.addLine(to: point(17.4, 18))
        path.closeSubpath()

        // Faille verticale évidée : le secret au cœur du sanctuaire.
        path.move(to: point(9.1, 3.1))
        path.addLine(to: point(9.65, 4.3))
        path.addLine(to: point(9.65, 15.8))
        path.addLine(to: point(8.75, 15.8))
        path.addLine(to: point(8.75, 4.3))
        path.closeSubpath()

        return path
    }
}
