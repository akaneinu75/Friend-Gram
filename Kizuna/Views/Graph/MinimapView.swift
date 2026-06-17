import SwiftUI

struct MinimapView: View {
    let persons: [Person]
    let relationships: [Relationship]
    let offset: CGSize
    let scale: CGFloat
    let canvasSize: CGSize
    let viewSize: CGSize
    var isLightBackground: Bool = false
    var onNavigate: ((CGSize) -> Void)? = nil

    private let mapWidth: CGFloat = 120
    private let mapHeight: CGFloat = 80

    var body: some View {
        let bgColor       = isLightBackground ? Color(.systemGray6).opacity(0.88) : Color.black.opacity(0.60)
        let lineColor     = isLightBackground ? Color.black.opacity(0.35)      : Color.white.opacity(0.50)
        let defaultDot    = isLightBackground ? Color(.darkGray)               : Color.white
        let viewportColor = isLightBackground ? Color.accentColor.opacity(0.8) : Color.yellow.opacity(0.9)
        let borderColor   = isLightBackground ? Color(.systemGray3)            : Color.white.opacity(0.30)

        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(bgColor))

            for rel in relationships {
                guard let pA = rel.personA, let pB = rel.personB else { continue }
                let start = miniPos(pA.positionX, pA.positionY, size: size)
                let end   = miniPos(pB.positionX, pB.positionY, size: size)
                var path = Path()
                path.move(to: start)
                path.addLine(to: end)
                ctx.stroke(path, with: .color(lineColor), lineWidth: 0.8)
            }

            for p in persons {
                let pos = miniPos(p.positionX, p.positionY, size: size)
                let dot = CGRect(x: pos.x - 1.5, y: pos.y - 1.5, width: 3, height: 3)
                ctx.fill(Path(ellipseIn: dot), with: .color(primaryAffiliationColor(for: p, fallback: defaultDot)))
            }

            let vpRect = viewportRect(in: size)
            ctx.stroke(Path(vpRect), with: .color(viewportColor), lineWidth: 1.5)
        }
        .frame(width: mapWidth, height: mapHeight)
        .cornerRadius(6)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(borderColor, lineWidth: 1))
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    onNavigate?(graphOffset(for: value.location))
                }
        )
    }

    private var contentBounds: (minX: CGFloat, maxX: CGFloat, minY: CGFloat, maxY: CGFloat) {
        let pad: CGFloat = 0.08
        guard !persons.isEmpty else { return (-pad, 1 + pad, -pad, 1 + pad) }
        let xs = persons.map { CGFloat($0.positionX) }
        let ys = persons.map { CGFloat($0.positionY) }
        return (
            xs.min()! - pad,
            xs.max()! + pad,
            ys.min()! - pad,
            ys.max()! + pad
        )
    }

    private func primaryAffiliationColor(for person: Person, fallback: Color) -> Color {
        let sorted = (person.affiliations as? Set<Affiliation>)?
            .sorted { ($0.name ?? "") < ($1.name ?? "") }
        if let hex = sorted?.first?.colorHex {
            return Color(hex: hex)
        }
        return fallback
    }

    private func miniPos(_ rx: Double, _ ry: Double, size: CGSize) -> CGPoint {
        let b = contentBounds
        let nx = (CGFloat(rx) - b.minX) / (b.maxX - b.minX)
        let ny = (CGFloat(ry) - b.minY) / (b.maxY - b.minY)
        return CGPoint(x: nx * size.width, y: ny * size.height)
    }

    private func graphOffset(for tapPoint: CGPoint) -> CGSize {
        let b = contentBounds
        let rangeX = b.maxX - b.minX
        let rangeY = b.maxY - b.minY
        let normCx = (tapPoint.x / mapWidth) * rangeX + b.minX
        let normCy = (tapPoint.y / mapHeight) * rangeY + b.minY
        return CGSize(
            width:  (0.5 - normCx) * canvasSize.width  * scale,
            height: (0.5 - normCy) * canvasSize.height * scale
        )
    }

    private func viewportRect(in size: CGSize) -> CGRect {
        let b = contentBounds
        let rangeX = b.maxX - b.minX
        let rangeY = b.maxY - b.minY
        let normCx = 0.5 - offset.width  / (canvasSize.width  * scale)
        let normCy = 0.5 - offset.height / (canvasSize.height * scale)
        let normVpW = viewSize.width  / (canvasSize.width  * scale)
        let normVpH = viewSize.height / (canvasSize.height * scale)
        let mx = (normCx - b.minX) / rangeX * size.width
        let my = (normCy - b.minY) / rangeY * size.height
        let mw = normVpW / rangeX * size.width
        let mh = normVpH / rangeY * size.height
        return CGRect(x: mx - mw / 2, y: my - mh / 2, width: mw, height: mh)
    }
}
