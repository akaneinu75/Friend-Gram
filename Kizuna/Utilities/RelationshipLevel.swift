import SwiftUI

enum RelationshipLevel: Int16, CaseIterable {
    case neutral  = 1
    case mild     = 2
    case friendly = 3
    case close    = 4
    case special  = 5
    case bond     = 6

    var icon: String {
        switch self {
        case .neutral:  return "😐"
        case .mild:     return "🙂"
        case .friendly: return "😊"
        case .close:    return "😄"
        case .special:  return "❤️"
        case .bond:     return "💖"
        }
    }

    // SF Symbolで表示するアイコン（imageNameの画像が無い場合、iconより優先して使用）
    var sfSymbolName: String? {
        switch self {
        case .bond: return "heart.fill"
        default:    return nil
        }
    }

    var lineWidth: CGFloat {
        switch self {
        case .neutral:  return 8
        case .mild:     return 12
        case .friendly: return 18
        case .close:    return 24
        case .special:  return 32
        case .bond:     return 36
        }
    }

    var label: String {
        switch self {
        case .neutral:  return "知人"
        case .mild:     return "顔見知り"
        case .friendly: return "友人"
        case .close:    return "親友"
        case .special:  return "特別"
        case .bond:     return "絆"
        }
    }

    var imageName: String {
        switch self {
        case .neutral:  return "rel_level1"
        case .mild:     return "rel_level2"
        case .friendly: return "rel_level3"
        case .close:    return "rel_level4"
        case .special:  return "rel_level5"
        case .bond:     return "rel_level6"
        }
    }

    var badgeColor: Color {
        switch self {
        case .neutral:  return Color(white: 0.55)
        case .mild:     return Color(red: 0.4, green: 0.85, blue: 0.5)
        case .friendly: return Color(red: 0.3, green: 0.75, blue: 1.0)
        case .close:    return Color(red: 1.0, green: 0.75, blue: 0.2)
        case .special:  return Color(red: 1.0, green: 0.35, blue: 0.55)
        case .bond:     return Color(red: 0.9, green: 0.1, blue: 0.2)
        }
    }

    static func from(_ value: Int16) -> RelationshipLevel {
        RelationshipLevel(rawValue: value) ?? .friendly
    }
}
