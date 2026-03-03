//
//  JobsTrackerApp.swift
//  JobsTracker
//
//  Created by Marcos Leal on 3/2/26.
//

import SwiftUI
import SwiftData

@main
struct JobsTrackerApp: App {
    // Static so JobAnalysisCoordinator can access the container without
    // a reference to the App instance.
    static let sharedModelContainer: ModelContainer = {
        let schema = Schema([JobEntry.self, TechnicalSkill.self])
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
        }
        .modelContainer(JobsTrackerApp.sharedModelContainer)
    }
}
