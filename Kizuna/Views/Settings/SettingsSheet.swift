import SwiftUI
import CoreData

struct SettingsSheet: View {
    @AppStorage("graphBackgroundColorHex") private var colorHex = "#1E242E"
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var ctx
    @EnvironmentObject private var graphManager: ActiveGraphManager

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Graph.createdAt, ascending: true)])
    private var graphs: FetchedResults<Graph>

    @State private var showAddAlert = false
    @State private var newGraphName = ""
    @State private var editingGraph: Graph? = nil
    @State private var showDeleteAllConfirm = false

    var body: some View {
        NavigationView {
            List {
                Section("グラフ") {
                    ForEach(graphs, id: \.objectID) { graph in
                        graphRow(graph)
                    }
                    Button {
                        newGraphName = ""
                        showAddAlert = true
                    } label: {
                        Label("グラフを追加", systemImage: "plus")
                    }
                }

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
                        Label("このグラフの全データを削除", systemImage: "trash")
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
            .alert("グラフを追加", isPresented: $showAddAlert) {
                TextField("グラフ名", text: $newGraphName)
                Button("追加") {
                    let name = newGraphName.trimmingCharacters(in: .whitespaces)
                    if !name.isEmpty { graphManager.createGraph(name: name) }
                }
                Button("キャンセル", role: .cancel) {}
            }
            .sheet(isPresented: Binding(
                get: { editingGraph != nil },
                set: { if !$0 { editingGraph = nil } }
            )) {
                if let g = editingGraph {
                    GraphEditSheet(graph: g, isLastGraph: graphs.count <= 1)
                        .environment(\.managedObjectContext, ctx)
                        .environmentObject(graphManager)
                }
            }
            .confirmationDialog(
                "このグラフの全データを削除しますか？\nこの操作は取り消せません。",
                isPresented: $showDeleteAllConfirm,
                titleVisibility: .visible
            ) {
                Button("すべて削除", role: .destructive) { deleteCurrentGraphData() }
            }
        }
    }

    private func graphRow(_ graph: Graph) -> some View {
        Button {
            graphManager.switchTo(graph)
            dismiss()
        } label: {
            HStack {
                Image(systemName: graphManager.activeGraph?.objectID == graph.objectID
                      ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(graphManager.activeGraph?.objectID == graph.objectID
                                     ? .accentColor : Color(.tertiaryLabel))
                Text(graph.name ?? "")
                    .foregroundColor(.primary)
                Spacer()
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                editingGraph = graph
            } label: {
                Label("編集", systemImage: "pencil")
            }
            .tint(.blue)
        }
    }

    private func deleteCurrentGraphData() {
        guard let g = graphManager.activeGraph else { return }
        let personReq: NSFetchRequest<Person> = Person.fetchRequest()
        personReq.predicate = NSPredicate(format: "graph == %@", g)
        for obj in (try? ctx.fetch(personReq)) ?? [] { ctx.delete(obj) }
        let affReq: NSFetchRequest<Affiliation> = Affiliation.fetchRequest()
        affReq.predicate = NSPredicate(format: "graph == %@", g)
        for obj in (try? ctx.fetch(affReq)) ?? [] { ctx.delete(obj) }
        try? ctx.save()
        dismiss()
    }
}

private struct GraphEditSheet: View {
    let graph: Graph
    let isLastGraph: Bool

    @Environment(\.managedObjectContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var graphManager: ActiveGraphManager

    @State private var graphName = ""
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationView {
            Form {
                Section("グラフ名") {
                    TextField("グラフ名", text: $graphName)
                }
                if !isLastGraph {
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("このグラフを削除", systemImage: "trash")
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                }
            }
            .navigationTitle("グラフを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(graphName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                graphName = graph.name ?? ""
            }
            .confirmationDialog(
                "「\(graphName)」を削除しますか？\nこのグラフの全データが削除されます。",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("削除", role: .destructive) {
                    graphManager.deleteGraph(graph)
                    dismiss()
                }
            }
        }
    }

    private func save() {
        let trimmed = graphName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        graphManager.rename(graph, to: trimmed)
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
    let ctx = PersistenceController.preview.container.viewContext
    return SettingsSheet()
        .environment(\.managedObjectContext, ctx)
        .environmentObject(ActiveGraphManager(ctx: ctx))
}
