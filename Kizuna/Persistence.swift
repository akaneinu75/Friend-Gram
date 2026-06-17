import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let ctx = result.container.viewContext
        let p = Person(context: ctx)
        p.id = UUID()
        p.name = "プレビュー"
        p.positionX = 0.5
        p.positionY = 0.5
        p.createdAt = Date()
        try? ctx.save()
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        let c = NSPersistentContainer(name: "Kizuna")
        #if DEBUG
        let entityNames = c.managedObjectModel.entitiesByName.keys.sorted()
        assert(!entityNames.isEmpty, "Core Data model is empty — Kizuna.xcdatamodeld がバンドルに含まれていません。Xcode でターゲットメンバーシップを確認してください。")
        print("[CoreData] loaded entities: \(entityNames)")
        #endif
        if inMemory {
            c.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        if let desc = c.persistentStoreDescriptions.first {
            desc.shouldMigrateStoreAutomatically = true
            desc.shouldInferMappingModelAutomatically = true
        }
        c.loadPersistentStores { description, error in
            if let error = error as NSError? {
                #if DEBUG
                // スキーマ変更時に古いストアを削除して再作成する
                if let storeURL = description.url {
                    try? c.persistentStoreCoordinator
                        .destroyPersistentStore(at: storeURL, type: .sqlite, options: nil)
                }
                c.loadPersistentStores { _, retryError in
                    if let retryError = retryError as NSError? {
                        fatalError("Unresolved error \(retryError), \(retryError.userInfo)")
                    }
                }
                #else
                fatalError("Unresolved error \(error), \(error.userInfo)")
                #endif
            }
        }
        c.viewContext.automaticallyMergesChangesFromParent = true
        container = c
    }
}
