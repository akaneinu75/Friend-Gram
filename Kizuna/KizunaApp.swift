//
//  KizunaApp.swift
//  Kizuna
//
//  Created by Akane on 2026/06/04.
//

import SwiftUI

@main
struct KizunaApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
