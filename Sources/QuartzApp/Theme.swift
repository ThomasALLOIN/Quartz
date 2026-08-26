import AppKit
import SwiftUI

private final class StoneTextureStore: @unchecked Sendable {
    static let shared = StoneTextureStore()

    private let cache = NSCache<NSString, NSImage>()

    func image(named name: String, fileExtension: String = "jpg") -> NSImage? {
        let key = "\(name).\(fileExtension)" as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        guard
            let url = Bundle.module.url(forResource: name, withExtension: fileExtension),
            let image = NSImage(contentsOf: url)
        else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }
}

enum StoneTheme: String, CaseIterable, Identifiable {
    case lapis
    case blackMarble

    var id: String { rawValue }

    var name: String {
        switch self {
        case .lapis: "Lapis nuit"
        case .blackMarble: "Marbre noir"
        }
    }

    var usesDarkAppearance: Bool { true }

    var palette: StonePalette {
        switch self {
        case .lapis:
            StonePalette(
                textureName: "lapis",
                textureExtension: "jpg",
                backdrop: Color(hex: 0x0E1727),
                stoneLight: Color(hex: 0x27466F),
                stoneDark: Color(hex: 0x10213C),
                surface: Color(hex: 0x172D4D),
                elevated: Color(hex: 0x203B62).opacity(0.9),
                text: Color(hex: 0xF7F2E7),
                secondary: Color(hex: 0xB6C4D8),
                accent: Color(hex: 0xE0B95C),
                vein: Color(hex: 0x7898C5),
                shadow: Color.black.opacity(0.48)
            )
        case .blackMarble:
            StonePalette(
                textureName: "black-marble",
                textureExtension: "png",
                backdrop: Color(hex: 0x06080B),
                stoneLight: Color(hex: 0x343940),
                stoneDark: Color(hex: 0x090B0E),
                surface: Color(hex: 0x11151A),
                elevated: Color(hex: 0x242A31).opacity(0.92),
                text: Color(hex: 0xF4F3EF),
                secondary: Color(hex: 0xB0B6BE),
                accent: Color(hex: 0xA98755),
                vein: Color(hex: 0xC8CDD4),
                shadow: Color.black.opacity(0.66)
            )
        }
    }
}

struct StonePalette {
    let textureName: String
    let textureExtension: String
    let backdrop: Color
    let stoneLight: Color
    let stoneDark: Color
    let surface: Color
    let elevated: Color
    let text: Color
    let secondary: Color
    let accent: Color
    let vein: Color
    let shadow: Color
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255,
            opacity: alpha
        )
    }
}

struct StoneShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()
        path.move(to: CGPoint(x: w * 0.08, y: h * 0.28))
        path.addCurve(
            to: CGPoint(x: w * 0.29, y: h * 0.06),
            control1: CGPoint(x: w * 0.10, y: h * 0.13),
            control2: CGPoint(x: w * 0.18, y: h * 0.05)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.78, y: h * 0.09),
            control1: CGPoint(x: w * 0.45, y: -h * 0.01),
            control2: CGPoint(x: w * 0.67, y: h * 0.02)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.96, y: h * 0.42),
            control1: CGPoint(x: w * 0.91, y: h * 0.15),
            control2: CGPoint(x: w * 0.98, y: h * 0.27)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.78, y: h * 0.90),
            control1: CGPoint(x: w, y: h * 0.66),
            control2: CGPoint(x: w * 0.94, y: h * 0.85)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.25, y: h * 0.95),
            control1: CGPoint(x: w * 0.60, y: h * 1.00),
            control2: CGPoint(x: w * 0.39, y: h * 0.99)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.04, y: h * 0.61),
            control1: CGPoint(x: w * 0.10, y: h * 0.91),
            control2: CGPoint(x: w * 0.01, y: h * 0.79)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.08, y: h * 0.28),
            control1: CGPoint(x: -w * 0.01, y: h * 0.48),
            control2: CGPoint(x: w * 0.03, y: h * 0.37)
        )
        path.closeSubpath()
        return path
    }
}

/// Contour réservé au widget réduit : un socle continu et plusieurs aiguilles
/// taillées, réunies comme les gardiens d'une entrée minérale.
enum ObeliskMassifGeometry {
    static func path(in rect: CGRect) -> CGPath {
        let path = CGMutablePath()
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
        }

        path.move(to: point(0.035, 0.73))
        path.addLine(to: point(0.075, 0.55))
        path.addLine(to: point(0.13, 0.46))
        path.addLine(to: point(0.17, 0.30))
        path.addLine(to: point(0.22, 0.17))
        path.addLine(to: point(0.27, 0.11))
        path.addLine(to: point(0.31, 0.20))
        path.addLine(to: point(0.33, 0.23))
        path.addLine(to: point(0.37, 0.15))
        path.addLine(to: point(0.405, 0.06))
        path.addLine(to: point(0.46, 0.015))
        path.addLine(to: point(0.50, 0.11))
        path.addLine(to: point(0.54, 0.025))
        path.addLine(to: point(0.60, 0.07))
        path.addLine(to: point(0.64, 0.16))
        path.addLine(to: point(0.67, 0.20))
        path.addLine(to: point(0.70, 0.14))
        path.addLine(to: point(0.755, 0.075))
        path.addLine(to: point(0.80, 0.18))
        path.addLine(to: point(0.835, 0.43))
        path.addLine(to: point(0.91, 0.48))
        path.addLine(to: point(0.97, 0.66))
        path.addQuadCurve(to: point(0.90, 0.89), control: point(0.99, 0.80))
        path.addQuadCurve(to: point(0.50, 0.97), control: point(0.74, 1.00))
        path.addQuadCurve(to: point(0.08, 0.88), control: point(0.25, 0.99))
        path.addQuadCurve(to: point(0.035, 0.71), control: point(0.015, 0.82))
        path.closeSubpath()
        return path
    }
}

struct ObeliskMassifShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path(ObeliskMassifGeometry.path(in: rect))
    }
}

/// Bas-relief monochrome généré pour la silhouette compacte. Le premier passage
/// conserve la matière de chaque pierre ; le second extrait les ombres réelles
/// du raster sur les aiguilles arrière sans poser de géométrie par-dessus.
struct ObeliskRelief: View {
    let palette: StonePalette
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        GeometryReader { proxy in
            if let relief = StoneTextureStore.shared.image(
                named: "obelisk-relief-v1",
                fileExtension: "png"
            ) {
                ZStack {
                    reliefImage(relief, size: proxy.size)
                        .contrast(1.22)
                        .blendMode(.softLight)
                        .opacity(reduceTransparency ? 0.44 : 0.78)

                    reliefImage(relief, size: proxy.size)
                        .contrast(1.58)
                        .brightness(0.20)
                        .blendMode(.multiply)
                        .opacity(reduceTransparency ? 0.14 : 0.34)
                        .mask {
                            LinearGradient(
                                stops: [
                                    .init(color: .white, location: 0),
                                    .init(color: .white.opacity(0.92), location: 0.62),
                                    .init(color: .clear, location: 0.94)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        }
                }
                .clipped()
            }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    private func reliefImage(_ image: NSImage, size: CGSize) -> some View {
        Image(nsImage: image)
            .resizable()
            .interpolation(.high)
            .scaledToFill()
            .frame(width: size.width, height: size.height)
            .grayscale(1)
    }
}

struct StoneFill: View {
    let palette: StonePalette
    var compact = false
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [palette.stoneLight, palette.stoneDark],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                if let texture = StoneTextureStore.shared.image(
                    named: palette.textureName,
                    fileExtension: palette.textureExtension
                ) {
                    Image(nsImage: texture)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .saturation(compact ? 0.96 : 0.88)
                        .contrast(compact ? 1.04 : 0.96)
                        .opacity(reduceTransparency ? 0.16 : (compact ? 0.88 : 0.72))
                        .clipped()
                }

                LinearGradient(
                    colors: [
                        palette.stoneLight.opacity(compact ? 0.10 : 0.18),
                        palette.stoneDark.opacity(compact ? 0.16 : 0.24)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .blendMode(.softLight)

                RadialGradient(
                    colors: [
                        Color.white.opacity(compact ? 0.34 : 0.22),
                        Color.clear
                    ],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: compact ? 118 : 520
                )

                if compact {
                    RadialGradient(
                        colors: [palette.surface.opacity(0.58), palette.surface.opacity(0.06), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 74
                    )
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}
