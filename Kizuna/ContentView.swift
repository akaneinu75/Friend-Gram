import SwiftUI

struct ContentView: View {
    @EnvironmentObject var graphManager: ActiveGraphManager

    var body: some View {
        if let graph = graphManager.activeGraph {
            MainTabView(graph: graph)
                .id(graph.objectID)
        }
    }
}

private struct MainTabView: View {
    let graph: Graph
    @AppStorage("graphBackgroundColorHex") private var bgColorHex = "#1E242E"

    private var tabBarBg: Color {
        Color.isLight(hex: bgColorHex) ? Color(.systemBackground) : Color(.systemGray4)
    }

    var body: some View {
        TabView {
            GraphView(graph: graph)
                .tabItem {
                    Label("グラフ", systemImage: "point.3.connected.trianglepath.dotted")
                }
                .toolbarBackground(tabBarBg, for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
            PersonListView(graph: graph)
                .tabItem {
                    Label("リスト", systemImage: "list.bullet")
                }
                .toolbarBackground(tabBarBg, for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
            MemoryQuizView(graph: graph)
                .tabItem {
                    Label("クイズ", systemImage: "person.crop.rectangle.stack")
                }
                .toolbarBackground(tabBarBg, for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
        }
    }
}

#Preview {
    let ctx = PersistenceController.preview.container.viewContext
    return GraphView(graph: {
        let g = Graph(context: ctx)
        g.id = UUID(); g.name = "Preview"; g.createdAt = Date()
        return g
    }())
    .environment(\.managedObjectContext, ctx)
    .environmentObject(ActiveGraphManager(ctx: ctx))
}
