import SwiftUI

struct PhotoCropView: View {
    let image: UIImage
    let onComplete: (UIImage) -> Void
    let onCancel: () -> Void

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let cropSize: CGFloat = 300
    private let outputSize: CGFloat = 600

    // scaledToFill 相当（cropSize の正方形を覆う表示サイズ、scale=1 時）
    private var fillSize: CGSize {
        let aspect = image.size.width / image.size.height
        if aspect > 1 {
            return CGSize(width: cropSize * aspect, height: cropSize)
        } else {
            return CGSize(width: cropSize, height: cropSize / aspect)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .frame(width: fillSize.width * scale, height: fillSize.height * scale)
                        .offset(offset)
                }
                .frame(width: cropSize, height: cropSize)
                .clipped()
                .overlay(Circle().stroke(Color.white.opacity(0.8), lineWidth: 1))
                .overlay(Rectangle().stroke(Color.white, lineWidth: 1))
                .contentShape(Rectangle())
                .gesture(dragGesture)
                .simultaneousGesture(magnificationGesture)

                Text("ピンチで拡大縮小、ドラッグで位置を調整")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()
            }
            .navigationTitle("写真を切り取り")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { complete() }
                }
            }
        }
    }

    // MARK: - Gestures

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = clampedOffset(CGSize(
                    width:  lastOffset.width  + value.translation.width,
                    height: lastOffset.height + value.translation.height
                ))
            }
            .onEnded { _ in
                lastOffset = offset
            }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = max(1.0, min(4.0, lastScale * value))
                offset = clampedOffset(offset)
            }
            .onEnded { _ in
                lastScale = scale
                offset = clampedOffset(offset)
                lastOffset = offset
            }
    }

    private func clampedOffset(_ proposed: CGSize) -> CGSize {
        let displayedWidth  = fillSize.width  * scale
        let displayedHeight = fillSize.height * scale
        let maxX = max(0, (displayedWidth  - cropSize) / 2)
        let maxY = max(0, (displayedHeight - cropSize) / 2)
        return CGSize(
            width:  min(max(proposed.width,  -maxX), maxX),
            height: min(max(proposed.height, -maxY), maxY)
        )
    }

    // MARK: - Crop

    private func complete() {
        let totalScale = (fillSize.width * scale) / image.size.width
        let cropSizeInImagePoints = cropSize / totalScale
        let cropOriginX = (fillSize.width  * scale / 2 - cropSize / 2 - offset.width)  / totalScale
        let cropOriginY = (fillSize.height * scale / 2 - cropSize / 2 - offset.height) / totalScale
        let outputScale = outputSize / cropSizeInImagePoints

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: outputSize, height: outputSize))
        let result = renderer.image { _ in
            let drawRect = CGRect(
                x: -cropOriginX * outputScale,
                y: -cropOriginY * outputScale,
                width:  image.size.width  * outputScale,
                height: image.size.height * outputScale
            )
            image.draw(in: drawRect)
        }
        onComplete(result)
    }
}

#Preview {
    PhotoCropView(
        image: UIImage(systemName: "person.fill") ?? UIImage(),
        onComplete: { _ in },
        onCancel: {}
    )
}
