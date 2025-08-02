//
//  RyFocusApp.swift
//  RyFocus
//
//  Created by Ryan Mitts on 2025-08-01.
//

import SwiftData
import SwiftUI

@main
struct RyFocusApp: App {
    @State private var appModel = AppModel()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            ImageStack.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appModel).frame(minWidth: 375.0, minHeight: 375.0)
                // Keeps the current window's size for use in scrolling header calculations.
                .onGeometryChange(for: CGSize.self) { geometry in
                    geometry.size
                } action: {
                    appModel.windowSize = $0
                }
        }
        .modelContainer(sharedModelContainer)

    }
}
