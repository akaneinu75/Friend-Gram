import SwiftUI

struct RelationshipEdgeView: View {
    let relationship: Relationship
    let viewModel: GraphViewModel
    let viewSize: CGSize

    var body: some View {
        guard let pA = relationship.personA, let pB = relationship.personB else {
            return AnyView(EmptyView())
        }
        let start = viewModel.graphToScreen(CGPoint(x: pA.positionX, y: pA.positionY), in: viewSize)
        let end   = viewModel.graphToScreen(CGPoint(x: pB.positionX, y: pB.positionY), in: viewSize)
        let mid   = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
        let level = RelationshipLevel.from(relationship.level)

        return AnyView(
            ZStack {
                Text(level.icon)
                    .font(.system(size: 18 * viewModel.scale))
                    .position(mid)

                if let label = relationship.label, !label.isEmpty {
                    Text(label)
                        .font(.system(size: 11 * viewModel.scale, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(4)
                        .position(x: mid.x, y: mid.y + 18 * viewModel.scale)
                }
            }
        )
    }
}
