import CoreData
import SwiftUI

class ActiveGraphManager: ObservableObject {
    @Published var activeGraph: Graph?

    private let ctx: NSManagedObjectContext

    init(ctx: NSManagedObjectContext) {
        self.ctx = ctx

        let req = Graph.fetchRequest()
        req.sortDescriptors = [NSSortDescriptor(keyPath: \Graph.createdAt, ascending: true)]
        let graphs = (try? ctx.fetch(req)) ?? []

        let storedID = UserDefaults.standard.string(forKey: "activeGraphID")
        let stored = graphs.first { $0.id?.uuidString == storedID }

        if graphs.isEmpty {
            let g = makeGraph(name: "グラフ 1")
            try? ctx.save()
            migrateOrphans(to: g)
            UserDefaults.standard.set(g.id?.uuidString, forKey: "activeGraphID")
            activeGraph = g
        } else {
            let active = stored ?? graphs[0]
            migrateOrphans(to: active)
            activeGraph = active
        }
    }

    func switchTo(_ graph: Graph) {
        activeGraph = graph
        UserDefaults.standard.set(graph.id?.uuidString, forKey: "activeGraphID")
    }

    @discardableResult
    func createGraph(name: String) -> Graph {
        let g = makeGraph(name: name)
        try? ctx.save()
        return g
    }

    func deleteGraph(_ graph: Graph) {
        let isActive = activeGraph?.objectID == graph.objectID
        ctx.delete(graph)
        try? ctx.save()

        guard isActive else { return }
        let req = Graph.fetchRequest()
        req.sortDescriptors = [NSSortDescriptor(keyPath: \Graph.createdAt, ascending: true)]
        let remaining = (try? ctx.fetch(req)) ?? []
        if let first = remaining.first {
            switchTo(first)
        } else {
            let new = createGraph(name: "グラフ 1")
            switchTo(new)
        }
    }

    func rename(_ graph: Graph, to name: String) {
        graph.name = name
        try? ctx.save()
    }

    private func makeGraph(name: String) -> Graph {
        let g = Graph(context: ctx)
        g.id = UUID()
        g.name = name
        g.createdAt = Date()
        return g
    }

    private func migrateOrphans(to graph: Graph) {
        let personReq = Person.fetchRequest()
        personReq.predicate = NSPredicate(format: "graph == nil")
        let orphanPersons = (try? ctx.fetch(personReq)) ?? []
        orphanPersons.forEach { $0.graph = graph }

        let affReq = Affiliation.fetchRequest()
        affReq.predicate = NSPredicate(format: "graph == nil")
        let orphanAffs = (try? ctx.fetch(affReq)) ?? []
        orphanAffs.forEach { $0.graph = graph }

        if !orphanPersons.isEmpty || !orphanAffs.isEmpty {
            try? ctx.save()
        }
    }
}
