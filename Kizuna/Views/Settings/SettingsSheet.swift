import SwiftUI
import CoreData

struct SettingsSheet: View {
    @AppStorage("graphBackgroundColorHex") private var colorHex = "#1E242E"
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var ctx
    @State private var showDeleteAllConfirm = false

    var body: some View {
        NavigationView {
            List {
                Section("表示") {
                    NavigationLink {
                        BackgroundColorPickerView()
                    } label: {
                        HStack {
                            Label("背景色", systemImage: "paintpalette.fill")
                            Spacer()
                            Circle()
                                .fill(Color(hex: colorHex))
                                .frame(width: 22, height: 22)
                                .overlay(Circle().stroke(Color(.systemGray4), lineWidth: 1))
                        }
                    }
                }
                Section("データ管理") {
                    Button(role: .destructive) {
                        showDeleteAllConfirm = true
                    } label: {
                        Label("すべての人物・関係性を削除", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .confirmationDialog(
                "すべての人物・関係性・所属を削除しますか？\nこの操作は取り消せません。",
                isPresented: $showDeleteAllConfirm,
                titleVisibility: .visible
            ) {
                Button("すべて削除", role: .destructive) { deleteAllData() }
            }
        }
    }

    private func deleteAllData() {
        for obj in (try? ctx.fetch(Person.fetchRequest())) ?? [] {
            ctx.delete(obj)
        }
        for obj in (try? ctx.fetch(Relationship.fetchRequest())) ?? [] {
            ctx.delete(obj)
        }
        for obj in (try? ctx.fetch(Affiliation.fetchRequest())) ?? [] {
            ctx.delete(obj)
        }
        try? ctx.save()
        dismiss()
    }
}

private struct BackgroundColorPickerView: View {
    @AppStorage("graphBackgroundColorHex") private var colorHex = "#1E242E"

    private let darkPresets: [(name: String, hex: String)] = [
        ("ネイビー",   "#1A2744"),
        ("グレー",     "#3D3D3D"),
        ("ブルー",     "#1A3A6B"),
        ("グリーン",   "#1A4A2E"),
        ("パープル",   "#3A1A6B"),
        ("レッド",     "#6B1A1A"),
    ]

    private let lightPresets: [(name: String, hex: String)] = [
        ("ホワイト",         "#FFFFFF"),
        ("ライトグレー",     "#F2F2F7"),
        ("クリーム",         "#FFF8EE"),
        ("ライトブルー",     "#EBF4FF"),
        ("ライトグリーン",   "#EBFAF0"),
        ("ライトパープル",   "#F5EBFF"),
    ]

    var body: some View {
        List {
            Section("ダーク系") {
                colorGrid(darkPresets)
            }
            Section("ライト系") {
                colorGrid(lightPresets)
            }
        }
        .navigationTitle("背景色")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func colorGrid(_ presets: [(name: String, hex: String)]) -> some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
            spacing: 24
        ) {
            ForEach(presets, id: \.hex) { preset in
                colorSwatch(preset)
            }
        }
        .padding(.vertical, 12)
    }

    private func colorSwatch(_ preset: (name: String, hex: String)) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color(hex: preset.hex))
                    .frame(width: 52, height: 52)
                    .shadow(color: .black.opacity(0.2), radius: 4)
                    .overlay(Circle().stroke(Color(.systemGray4), lineWidth: 1))
                if colorHex == preset.hex {
                    Circle()
                        .stroke(Color.accentColor, lineWidth: 3)
                        .frame(width: 62, height: 62)
                }
            }
            Text(preset.name)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .onTapGesture { colorHex = preset.hex }
    }
}

#Preview {
    SettingsSheet()
}
