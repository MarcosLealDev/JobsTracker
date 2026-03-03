//
//  JobListView.swift
//  JobsTracker
//
//  Created by Marcos Leal on 3/2/26.
//

import SwiftUI
import SwiftData

struct JobListView: View {
    @Query(sort: \JobEntry.createdAt, order: .reverse) private var entries: [JobEntry]
    @Environment(\.modelContext) private var modelContext
    @Binding var selectedEntry: JobEntry?

    @State private var showingNewJobSheet = false

    var body: some View {
        List(selection: $selectedEntry) {
            ForEach(entries) { entry in
                JobRowView(entry: entry)
                    .tag(entry)
            }
            .onDelete(perform: deleteEntries)
        }
        .navigationTitle("Jobs")
        .navigationSplitViewColumnWidth(min: 220, ideal: 280)
        .toolbar {
            ToolbarItem {
                Button {
                    showingNewJobSheet = true
                } label: {
                    Label("Add Job", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingNewJobSheet) {
            NewJobSheet()
        }
        .overlay {
            if entries.isEmpty {
                ContentUnavailableView(
                    "No Jobs Yet",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Press + to add a job description.")
                )
            }
        }
    }

    private func deleteEntries(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(entries[index])
        }
    }
}

// MARK: - Job Row

struct JobRowView: View {
    let entry: JobEntry

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(entry.jobPosition ?? "Untitled Position")
                        .font(.headline)
                        .lineLimit(1)

                    if entry.allSkillsKnown {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                            .font(.caption)
                    }
                }

                Text(entry.companyName ?? entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            statusIcon
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch entry.status {
        case .pending:
            Image(systemName: "clock")
                .foregroundStyle(.secondary)
                .font(.caption)
        case .analyzing:
            ProgressView()
                .scaleEffect(0.65)
                .frame(width: 16, height: 16)
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.caption)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .font(.caption)
        }
    }
}

#Preview {
    NavigationSplitView {
        JobListView(selectedEntry: .constant(nil))
    } detail: {
        Text("Select a job")
    }
    .modelContainer(ModelContainer.preview)
}
