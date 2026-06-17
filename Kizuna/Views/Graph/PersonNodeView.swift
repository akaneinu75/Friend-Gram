import SwiftUI

struct PersonNodeView: View {
    @ObservedObject var person: Person
    let isSelected: Bool
    let scale: CGFloat
    var maskName: Bool = false
    var maskFace: Bool = false
    var isLightBackground: Bool = false

    // 写真のデコード結果をキャッシュし、scale変化による毎フレーム再描画時の再デコードを防ぐ
    @State private var cachedImage: UIImage?

    private let photoSize: CGFloat = 62
    private let ringSize: CGFloat = 72

    private var affiliationColors: [Color] {
        let affs = (person.affiliations as? Set<Affiliation>)?
            .sorted { ($0.name ?? "") < ($1.name ?? "") } ?? []
        return affs.map { Color(hex: $0.colorHex ?? "#3498DB") }
    }

    var body: some View {
        VStack(spacing: 2 * scale) {
            ZStack {
                // 所属カラーをfillで描画（隙間ゼロ）
                AffiliationFill(colors: affiliationColors, diameter: ringSize * scale, isLightBackground: isLightBackground)

                // 写真 or イニシャル（リングより小さい円で重ねる）
                photoView
                    .frame(width: photoSize * scale, height: photoSize * scale)
                    .clipShape(Circle())

                // 選択リング
                if isSelected {
                    Circle()
                        .stroke(Color.yellow, lineWidth: 3 * scale)
                        .frame(width: (ringSize + 6) * scale, height: (ringSize + 6) * scale)
                }
            }

            Text(maskName ? "●●●" : (person.name ?? ""))
                .font(.system(size: 14 * scale, weight: .medium))
                .foregroundColor(isLightBackground ? Color(.label) : .white)
        }
        .task(id: person.photoData) {
            cachedImage = person.photoData.flatMap { UIImage(data: $0) }
        }
    }

    @ViewBuilder
    private var photoView: some View {
        if maskFace {
            Circle()
                .fill(Color(.systemGray3))
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 20 * scale))
                        .foregroundColor(.white.opacity(0.5))
                )
        } else if let ui = cachedImage ?? person.photoData.flatMap({ UIImage(data: $0) }) {
            Image(uiImage: ui)
                .resizable()
                .scaledToFill()
        } else {
            Circle()
                .fill(Color(.systemGray3))
                .overlay(
                    Text(String((person.name ?? "").prefix(1)))
                        .font(.system(size: 20 * scale, weight: .bold))
                        .foregroundColor(.white)
                )
        }
    }
}

// 塗りつぶし方式のリング（strokeではなくfillなので隙間が生じない）
private struct AffiliationFill: View {
    let colors: [Color]
    let diameter: CGFloat
    var isLightBackground: Bool = false

    var body: some View {
        Canvas { ctx, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let r = min(size.width, size.height) / 2

            if colors.isEmpty {
                ctx.fill(Path(ellipseIn: CGRect(origin: .zero, size: size)),
                         with: .color(isLightBackground ? Color(.systemGray2) : .gray))
            } else if colors.count == 1 {
                ctx.fill(Path(ellipseIn: CGRect(origin: .zero, size: size)),
                         with: .color(colors[0]))
            } else {
                let slice = 2 * CGFloat.pi / CGFloat(colors.count)
                for (i, color) in colors.enumerated() {
                    let start = slice * CGFloat(i) - .pi / 2
                    let end   = start + slice
                    var path = Path()
                    path.move(to: center)
                    path.addArc(center: center, radius: r,
                                startAngle: .radians(start),
                                endAngle: .radians(end),
                                clockwise: false)
                    path.closeSubpath()
                    ctx.fill(path, with: .color(color))
                }
            }
        }
        .frame(width: diameter, height: diameter)
        .clipShape(Circle())
    }
}
