import SwiftUI
import CoreData

struct GraphExportView: View {
    let persons: [Person]
    let relationships: [Relationship]
    let maskNames: Bool
    let maskFaces: Bool
    let backgroundColor: Color

    private let canvasSize = CGSize(width: 2000, height: 2000)
    static let exportSize  = CGSize(width: 1200, height: 1200)

    private var fitParams: (scale: CGFloat, offset: CGSize) {
        guard !persons.isEmpty else { return (1.0, .zero) }
        let pad: CGFloat = 0.05
        let xs = persons.map { CGFloat($0.positionX) }
        let ys = persons.map { CGFloat($0.positionY) }
        let spanX = max((xs.max()! - xs.min()!) + 2 * pad, 0.15)
        let spanY = max((ys.max()! - ys.min()!) + 2 * pad, 0.15)
        let s = min(
            Self.exportSize.width  / (spanX * canvasSize.width),
            Self.exportSize.height / (spanY * canvasSize.height),
            1.5
        )
        let cx = (xs.min()! + xs.max()!) / 2
        let cy = (ys.min()! + ys.max()!) / 2
        let off = CGSize(
            width:  (0.5 - cx) * canvasSize.width  * s,
            height: (0.5 - cy) * canvasSize.height * s
        )
        return (s, off)
    }

    var body: some View {
        let (s, off) = fitParams
        ZStack {
            backgroundColor
            GraphCanvasLayer(
                persons: persons,
                relationships: relationships,
                offset: off,
                scale: s,
                canvasSize: canvasSize,
                viewSize: Self.exportSize,
                dragSourcePerson: nil,
                dragCurrentPosition: nil,
                draggingPerson: nil,
                draggingScreenPosition: .zero,
                contextRevision: 0,
                isLightBackground: backgroundColor.isLight
            )
            ForEach(persons, id: \.objectID) { person in
                PersonNodeView(
                    person: person,
                    isSelected: false,
                    scale: s,
                    maskName: maskNames,
                    maskFace: maskFaces,
                    isLightBackground: backgroundColor.isLight
                )
                .position(nodePosition(of: person, scale: s, offset: off))
            }
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Image(backgroundColor.isLight ? "black" : "white")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 60, height: 60)
                        Text("Friend Gram")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(backgroundColor.isLight ? .black.opacity(1.0) : .white.opacity(1.0))
                    }
                    .padding(.trailing, 16)
                }
            }
            .padding(28)
        }
        .frame(width: Self.exportSize.width, height: Self.exportSize.height)
    }

    private func nodePosition(of person: Person, scale: CGFloat, offset: CGSize) -> CGPoint {
        let x = (person.positionX * canvasSize.width  - canvasSize.width  / 2) * scale
            + Self.exportSize.width  / 2 + offset.width
        let y = (person.positionY * canvasSize.height - canvasSize.height / 2) * scale
            + Self.exportSize.height / 2 + offset.height
        let textLineHeight = 14.0 * 1.25 * scale
        let spacing = 2.0 * scale
        let nodeYOffset = (textLineHeight + spacing) / 2.0
        return CGPoint(x: x, y: y + nodeYOffset)
    }
}

#Preview {
    GraphExportView(
        persons: [],
        relationships: [],
        maskNames: false,
        maskFaces: false,
        backgroundColor: Color(hex: "#1E242E")
    )
}
