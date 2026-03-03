//
//  ContentView.swift
//  JobsTracker
//
//  Created by Marcos Leal on 3/2/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedEntry: JobEntry?

    var body: some View {
        NavigationSplitView {
            JobListView(selectedEntry: $selectedEntry)
        } detail: {
            if let entry = selectedEntry {
                JobDetailView(entry: entry, selectedEntry: $selectedEntry)
            } else {
                ContentUnavailableView(
                    "No Job Selected",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Select a job entry or press + to add a new one.")
                )
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(ModelContainer.preview)
}
