import SwiftUI

struct ContentView: View {
    @AppStorage("graphBackgroundColorHex") private var bgColorHex = "#1E242E"

    private var tabBarBg: Color {
        Color.isLight(hex: bgColorHex) ? Color(.systemBackground) : Color(.systemGray4)
    }

    var body: some View {
        TabView {
            GraphView()
                .tabItem {
                    Label("グラフ", systemImage: "point.3.connected.trianglepath.dotted")
                }
                .toolbarBackground(tabBarBg, for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
            PersonListView()
                .tabItem {
                    Label("リスト", systemImage: "list.bullet")
                }
                .toolbarBackground(tabBarBg, for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
            MemoryQuizView()
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
    return GraphView()
        .environment(\.managedObjectContext, ctx)
}
