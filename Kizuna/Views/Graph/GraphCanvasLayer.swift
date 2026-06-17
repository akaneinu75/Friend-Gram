import SwiftUI
import CoreData

struct GraphCanvasLayer: View, Animatable {
    let persons: [Person]
    let relationships: [Relationship]
    var offset: CGSize
    var scale: CGFloat
    let canvasSize: CGSize
    let viewSize: CGSize
    let dragSourcePerson: Person?
    let dragCurrentPosition: CGPoint?
    let draggingPerson: Person?
    let draggingScreenPosition: CGPoint
    let contextRevision: Int
    var isLightBackground: Bool = false

    var animatableData: AnimatablePair<AnimatablePair<Double, Double>, Double> {
        get {
            AnimatablePair(
                AnimatablePair(Double(offset.width), Double(offset.height)),
                Double(scale)
            )
        }
        set {
            offset = CGSize(width: newValue.first.first, height: newValue.first.second)
            scale  = newValue.second
        }
    }

    var body: some View {
        let lineColor  = isLightBackground ? Color.black.opacity(0.18) : Color.white.opacity(0.35)
        let labelColor = isLightBackground ? Color.black.opacity(0.80) : Color.white.opacity(0.90)
        let badgeBg    = isLightBackground ? Color.white                : Color.white
        let dragColor  = isLightBackground ? Color.accentColor.opacity(0.8) : Color.yellow.opacity(0.8)

        Canvas { ctx, _ in
            for rel in relationships {
                guard let pA = rel.personA, let pB = rel.personB else { continue }
                let level    = RelationshipLevel.from(rel.level)
                let arrowDir = ArrowDirection.from(rel.arrowDirection)
                let start    = screenPos(of: pA)
                let end      = screenPos(of: pB)

                let dx   = end.x - start.x
                let dy   = end.y - start.y
                let dist = hypot(dx, dy)
                guard dist > 4 else { continue }
                let ux = dx / dist
                let uy = dy / dist

                let nodeR      = 36.0 * scale
                let lineW      = level.lineWidth * scale
                let triLength  = lineW * 0.6

                let hasSibling = relationships.contains { other in
                    other.objectID != rel.objectID &&
                    other.personA == pB && other.personB == pA
                }

                let fullMid = CGPoint(x: (start.x + end.x) / 2,
                                      y: (start.y + end.y) / 2)
                let badgeMid: CGPoint = hasSibling
                    ? CGPoint(x: (start.x + nodeR * ux + fullMid.x) / 2,
                               y: (start.y + nodeR * uy + fullMid.y) / 2)
                    : fullMid

                let strokeFrom: CGPoint
                let strokeTo: CGPoint
                let triTip: CGPoint
                let triDirX: CGFloat
                let triDirY: CGFloat
                let showTri: Bool

                switch arrowDir {
                case .aToB:
                    let tip = hasSibling
                        ? fullMid
                        : CGPoint(x: end.x - nodeR * ux, y: end.y - nodeR * uy)
                    triTip     = tip
                    triDirX    = ux;  triDirY = uy
                    strokeFrom = start
                    strokeTo   = CGPoint(x: tip.x - triLength * ux, y: tip.y - triLength * uy)
                    showTri    = true

                case .bToA:
                    let tip = CGPoint(x: start.x + nodeR * ux, y: start.y + nodeR * uy)
                    triTip     = tip
                    triDirX    = -ux; triDirY = -uy
                    strokeFrom = CGPoint(x: tip.x + triLength * ux, y: tip.y + triLength * uy)
                    strokeTo   = hasSibling ? fullMid : end
                    showTri    = true

                case .both:
                    triTip     = .zero; triDirX = 0; triDirY = 0
                    strokeFrom = start
                    strokeTo   = hasSibling ? fullMid : end
                    showTri    = false
                }

                var linePath = Path()
                linePath.move(to: strokeFrom)
                linePath.addLine(to: strokeTo)
                ctx.stroke(linePath,
                           with: .color(lineColor),
                           style: StrokeStyle(lineWidth: lineW, lineCap: .butt))

                if showTri {
                    ctx.fill(
                        triPath(tip: triTip, ux: triDirX, uy: triDirY,
                                length: triLength, wing: lineW / 2),
                        with: .color(lineColor)
                    )
                }

                let badgeR  = 12.0 * scale
                let bgRect  = CGRect(x: badgeMid.x - badgeR, y: badgeMid.y - badgeR,
                                     width: badgeR * 2, height: badgeR * 2)
                let hasImage = UIImage(named: level.imageName) != nil
                if !(level == .bond && hasImage) {
                    ctx.fill(Path(ellipseIn: bgRect), with: .color(badgeBg))
                    if isLightBackground {
                        ctx.stroke(Path(ellipseIn: bgRect), with: .color(Color(.systemGray3)), lineWidth: 0.5)
                    }
                }
                let imgR    = (level == .bond && hasImage) ? badgeR * 1.0 : badgeR * 0.85
                let imgRect = CGRect(x: badgeMid.x - imgR, y: badgeMid.y - imgR,
                                     width: imgR * 2, height: imgR * 2)
                if hasImage {
                    ctx.draw(ctx.resolve(Image(level.imageName)), in: imgRect)
                } else if let symbol = level.sfSymbolName {
                    ctx.draw(Text(Image(systemName: symbol))
                        .font(.system(size: badgeR * 1.5))
                                .foregroundColor(.red),
                             at: badgeMid, anchor: .center)
                } else {
                    ctx.draw(Text(level.icon).font(.system(size: imgR * 1.4)),
                             at: badgeMid, anchor: .center)
                }
                if let label = rel.label, !label.isEmpty {
                    ctx.draw(
                        Text(label)
                            .font(.system(size: 14 * scale, weight: .medium))
                            .foregroundColor(labelColor),
                        at: CGPoint(x: badgeMid.x, y: badgeMid.y + badgeR + 5 * scale),
                        anchor: .top
                    )
                }
            }

            if let src = dragSourcePerson, let cur = dragCurrentPosition {
                let start = screenPos(of: src)
                var path = Path()
                path.move(to: start)
                path.addLine(to: cur)
                ctx.stroke(path, with: .color(dragColor),
                           style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [8, 4]))
            }
        }
    }

    private func screenPos(of person: Person) -> CGPoint {
        if person == draggingPerson {
            return draggingScreenPosition
        }
        let x = (person.positionX * canvasSize.width  - canvasSize.width  / 2) * scale + viewSize.width  / 2 + offset.width
        let y = (person.positionY * canvasSize.height - canvasSize.height / 2) * scale + viewSize.height / 2 + offset.height
        return CGPoint(x: x, y: y)
    }

    private func triPath(tip: CGPoint, ux: CGFloat, uy: CGFloat,
                         length: CGFloat, wing: CGFloat) -> Path {
        let bx    = tip.x - length * ux
        let by    = tip.y - length * uy
        let base1 = CGPoint(x: bx - wing * uy, y: by + wing * ux)
        let base2 = CGPoint(x: bx + wing * uy, y: by - wing * ux)
        var path  = Path()
        path.move(to: tip)
        path.addLine(to: base1)
        path.addLine(to: base2)
        path.closeSubpath()
        return path
    }
}
