import SwiftUI

struct AnimatedPersonNode: View, Animatable {
    let person: Person
    let isSelected: Bool
    var offset: CGSize
    var scale: CGFloat
    let canvasSize: CGSize
    let viewSize: CGSize
    let draggingPerson: Person?
    let draggingScreenPosition: CGPoint
    var isLightBackground: Bool = false
    var contextRevision: Int = 0

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

    // PersonNodeView は VStack(circle + text)。
    // .position() は VStack 全体の中心に作用するため、
    // 円の中心が screenPos より下にずれる。
    // テキスト行高＋間隔の半分だけ下にずらして円の中心を screenPos に合わせる。
    private var nodeYOffset: CGFloat {
        let textLineHeight = 14.0 * 1.25 * scale  // font 14pt の行高
        let spacing = 2.0 * scale
        return (textLineHeight + spacing) / 2.0
    }

    var body: some View {
        PersonNodeView(person: person, isSelected: isSelected, scale: scale, isLightBackground: isLightBackground)
            .position(CGPoint(x: screenPos.x, y: screenPos.y + nodeYOffset))
    }

    private var screenPos: CGPoint {
        if person == draggingPerson {
            return draggingScreenPosition
        }
        let x = (person.positionX * canvasSize.width  - canvasSize.width  / 2) * scale + viewSize.width  / 2 + offset.width
        let y = (person.positionY * canvasSize.height - canvasSize.height / 2) * scale + viewSize.height / 2 + offset.height
        return CGPoint(x: x, y: y)
    }
}
