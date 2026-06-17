import Foundation

enum ArrowDirection: Int16, CaseIterable {
    case both = 0  // ↔ 双方向
    case aToB = 1  // A→B
    case bToA = 2  // B→A

    var sfSymbol: String {
        switch self {
        case .both: return "arrow.left.arrow.right"
        case .aToB: return "arrow.right"
        case .bToA: return "arrow.left"
        }
    }

    var name: String {
        switch self {
        case .both: return "双方向"
        case .aToB: return "→"
        case .bToA: return "←"
        }
    }

    static func from(_ value: Int16) -> ArrowDirection {
        ArrowDirection(rawValue: value) ?? .both
    }
}
