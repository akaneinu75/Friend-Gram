import SwiftUI
import CoreData

class GraphViewModel: ObservableObject {
    @Published var scale: CGFloat = 1.0
    @Published var offset: CGSize = .zero
    @Published var selectedPerson: Person?
    @Published var dragSourcePerson: Person?
    @Published var dragCurrentPosition: CGPoint?

    // ノードリアルタイム移動（CoreData saveなし）
    @Published var draggingPerson: Person?
    @Published var draggingScreenPosition: CGPoint = .zero

    // 新規人物追加
    @Published var addPersonPosition: CGPoint?
    @Published var showAddPerson = false

    // 関係作成
    @Published var showAddRelationship = false
    @Published var relationshipSource: Person?
    @Published var relationshipTarget: Person?

    // 関係編集
    @Published var editingRelationship: Relationship?
    @Published var showEditRelationship = false

    let canvasSize = CGSize(width: 2000, height: 2000)

    func screenToGraph(_ point: CGPoint, in viewSize: CGSize) -> CGPoint {
        let x = (point.x - offset.width - viewSize.width / 2) / scale + canvasSize.width / 2
        let y = (point.y - offset.height - viewSize.height / 2) / scale + canvasSize.height / 2
        return CGPoint(x: x / canvasSize.width, y: y / canvasSize.height)
    }

    func graphToScreen(_ relative: CGPoint, in viewSize: CGSize) -> CGPoint {
        let x = (relative.x * canvasSize.width - canvasSize.width / 2) * scale + viewSize.width / 2 + offset.width
        let y = (relative.y * canvasSize.height - canvasSize.height / 2) * scale + viewSize.height / 2 + offset.height
        return CGPoint(x: x, y: y)
    }

    func nodeRadius() -> CGFloat { 36 * scale }

    func hitTestPerson(_ persons: [Person], at point: CGPoint, in viewSize: CGSize) -> Person? {
        let r = nodeRadius()
        return persons.first { p in
            let center = screenPosition(of: p, in: viewSize)
            return hypot(point.x - center.x, point.y - center.y) < r
        }
    }

    // ドラッグ中はリアルタイム位置を返す
    func screenPosition(of person: Person, in viewSize: CGSize) -> CGPoint {
        if person == draggingPerson {
            return draggingScreenPosition
        }
        return graphToScreen(CGPoint(x: person.positionX, y: person.positionY), in: viewSize)
    }

    // ドラッグ中: メモリ上のみ更新（saveなし）
    func movePerson(_ person: Person, to screenPoint: CGPoint, in viewSize: CGSize) {
        draggingPerson = person
        draggingScreenPosition = screenPoint
    }

    // ドラッグ終了: CoreDataに保存
    func commitPersonPosition(_ person: Person, to screenPoint: CGPoint, in viewSize: CGSize, context: NSManagedObjectContext) {
        let rel = screenToGraph(screenPoint, in: viewSize)
        person.positionX = rel.x
        person.positionY = rel.y
        draggingPerson = nil
        try? context.save()
    }

    // 全人物の実際の配置範囲（+パディング、最小 [0,1]）
    func contentBounds(for persons: [Person]) -> (minX: CGFloat, maxX: CGFloat, minY: CGFloat, maxY: CGFloat) {
        let pad: CGFloat = 0.08
        guard !persons.isEmpty else { return (-pad, 1 + pad, -pad, 1 + pad) }
        let xs = persons.map { CGFloat($0.positionX) }
        let ys = persons.map { CGFloat($0.positionY) }
        return (
            min(0, xs.min()!) - pad,
            max(1, xs.max()!) + pad,
            min(0, ys.min()!) - pad,
            max(1, ys.max()!) + pad
        )
    }

    // パン量をコンテンツ境界内にクランプ（画面端から margin pt は常に見える）
    func clampedOffset(_ raw: CGSize, for persons: [Person], in viewSize: CGSize) -> CGSize {
        let b = contentBounds(for: persons)
        let margin: CGFloat = 80
        let cL = (b.minX - 0.5) * canvasSize.width  * scale
        let cR = (b.maxX - 0.5) * canvasSize.width  * scale
        let cT = (b.minY - 0.5) * canvasSize.height * scale
        let cB = (b.maxY - 0.5) * canvasSize.height * scale
        let minX = margin - viewSize.width  / 2 - cR
        let maxX = viewSize.width  / 2 - margin - cL
        let minY = margin - viewSize.height / 2 - cB
        let maxY = viewSize.height / 2 - margin - cT
        return CGSize(
            width:  minX <= maxX ? min(max(raw.width,  minX), maxX) : raw.width,
            height: minY <= maxY ? min(max(raw.height, minY), maxY) : raw.height
        )
    }

    func centerAllOffset(for persons: [Person], in viewSize: CGSize) -> CGSize {
        guard !persons.isEmpty else { return .zero }
        let cx = persons.map(\.positionX).reduce(0, +) / Double(persons.count)
        let cy = persons.map(\.positionY).reduce(0, +) / Double(persons.count)
        return CGSize(
            width:  (0.5 - cx) * canvasSize.width  * scale,
            height: (0.5 - cy) * canvasSize.height * scale
        )
    }

    // 指定人物を画面中央に表示するオフセット（検索結果へのジャンプ用）
    func offsetToCenter(_ person: Person, in viewSize: CGSize) -> CGSize {
        CGSize(
            width:  (0.5 - person.positionX) * canvasSize.width  * scale,
            height: (0.5 - person.positionY) * canvasSize.height * scale
        )
    }

    func centeredOffset(for person: Person, in viewSize: CGSize) -> CGSize {
        let targetY = viewSize.height * 0.28
        return CGSize(
            width:  (0.5 - person.positionX) * canvasSize.width  * scale,
            height: (0.5 - person.positionY) * canvasSize.height * scale - (viewSize.height / 2 - targetY)
        )
    }

    func hitTestRelationship(_ relationships: [Relationship], at point: CGPoint, in viewSize: CGSize) -> Relationship? {
        let threshold: CGFloat = 12
        var best: Relationship?
        var bestDist = threshold

        for rel in relationships {
            guard let pA = rel.personA, let pB = rel.personB else { continue }
            let start = screenPosition(of: pA, in: viewSize)
            let end   = screenPosition(of: pB, in: viewSize)

            // sibling がある場合は描画された半セグメントで判定
            let hasSibling = relationships.contains { other in
                other.objectID != rel.objectID &&
                other.personA == pB && other.personB == pA
            }
            let segEnd = hasSibling
                ? CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
                : end

            let d = distanceFromPoint(point, toSegment: start, end: segEnd)
            if d < bestDist {
                bestDist = d
                best = rel
            }
        }
        return best
    }

    private func distanceFromPoint(_ p: CGPoint, toSegment a: CGPoint, end b: CGPoint) -> CGFloat {
        let ab = CGPoint(x: b.x - a.x, y: b.y - a.y)
        let ap = CGPoint(x: p.x - a.x, y: p.y - a.y)
        let len2 = ab.x * ab.x + ab.y * ab.y
        guard len2 > 0 else { return hypot(ap.x, ap.y) }
        let t = max(0, min(1, (ap.x * ab.x + ap.y * ab.y) / len2))
        let closest = CGPoint(x: a.x + t * ab.x, y: a.y + t * ab.y)
        return hypot(p.x - closest.x, p.y - closest.y)
    }
}
