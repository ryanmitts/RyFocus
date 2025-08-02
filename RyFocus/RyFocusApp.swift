//
//  RyFocusApp.swift
//  RyFocus
//
//  Created by Ryan Mitts on 2025-08-01.
//

import SwiftUI
import SwiftData

@main
struct RyFocusApp: App {
    @State private var appModel = AppModel()
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            ImageStack.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appModel)
        }
        .modelContainer(sharedModelContainer)
    }
}
