import SwiftUI

@main
struct KizunaApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var graphManager: ActiveGraphManager

    init() {
        let ctx = PersistenceController.shared.container.viewContext
        _graphManager = StateObject(wrappedValue: ActiveGraphManager(ctx: ctx))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(graphManager)
        }
    }
}
