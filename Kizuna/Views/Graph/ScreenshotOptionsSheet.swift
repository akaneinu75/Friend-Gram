import SwiftUI
import Photos
import CoreData

struct ScreenshotOptionsSheet: View {
    let persons: [Person]
    let relationships: [Relationship]
    let backgroundColor: Color

    @Environment(\.dismiss) private var dismiss
    @State private var maskNames = false
    @State private var maskFaces = false
    @State private var isRendering = false
    @State private var alertMessage = ""
    @State private var showAlert = false

    var body: some View {
        NavigationView {
            Form {
                Section("マスク設定") {
                    Toggle("名前を隠す", isOn: $maskNames)
                    Toggle("顔写真を隠す", isOn: $maskFaces)
                }
                Section {
                    Button {
                        Task { await renderAndSave() }
                    } label: {
                        HStack {
                            Spacer()
                            if isRendering {
                                ProgressView()
                                    .padding(.vertical, 4)
                            } else {
                                Text("写真に保存する")
                                    .font(.headline)
                            }
                            Spacer()
                        }
                    }
                    .disabled(isRendering)
                }
            }
            .navigationTitle("スクリーンショット")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
        .alert(alertMessage, isPresented: $showAlert) {
            Button("OK") {}
        }
    }

    @MainActor
    private func renderAndSave() async {
        isRendering = true
        let view = GraphExportView(
            persons: persons,
            relationships: relationships,
            maskNames: maskNames,
            maskFaces: maskFaces,
            backgroundColor: backgroundColor
        )
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2.0
        isRendering = false

        guard let img = renderer.uiImage else {
            alertMessage = "画像の生成に失敗しました"
            showAlert = true
            return
        }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: img)
            }
            alertMessage = "写真ライブラリに保存しました"
            showAlert = true
        } catch {
            alertMessage = "保存に失敗しました\n\(error.localizedDescription)"
            showAlert = true
        }
    }
}

#Preview {
    ScreenshotOptionsSheet(
        persons: [],
        relationships: [],
        backgroundColor: Color(hex: "#1E242E")
    )
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
