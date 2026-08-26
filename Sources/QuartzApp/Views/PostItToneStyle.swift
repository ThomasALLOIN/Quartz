import QuartzKit
import SwiftUI

extension PostItTone {
    var paperColor: Color {
        switch self {
        case .sage:
            Color(red: 0.65, green: 0.84, blue: 0.43)
        case .parchment, .rose, .lavender:
            // Rose et lavande restent décodables uniquement pour préserver
            // les anciennes données ; elles sont rendues comme le jaune permanent.
            Color(red: 0.96, green: 0.83, blue: 0.37)
        }
    }

    var inkColor: Color { Color.black.opacity(0.76) }
}

extension PostItMode {
    var color: Color {
        switch self {
        case .off: Color.gray
        case .persistent: PostItTone.parchment.paperColor
        case .daily: PostItTone.sage.paperColor
        }
    }

    var label: String {
        switch self {
        case .off: "Désactivé"
        case .persistent: "Jaune · toujours"
        case .daily: "Vert · daily"
        }
    }

    var nextActionHelp: String {
        switch self {
        case .off: "Activer les post-it jaunes toujours visibles"
        case .persistent: "Passer aux post-it verts daily"
        case .daily: "Désactiver le mode post-it"
        }
    }
}
