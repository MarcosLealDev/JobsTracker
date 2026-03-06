//
//  NewJobSheet.swift
//  JobsTracker
//
//  Created by Marcos Leal on 3/2/26.
//

import SwiftUI
import SwiftData

struct NewJobSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var jobURL: String = ""
    @State private var pastedText: String = ""
    @State private var isScraping = false
    @State private var scrapeError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("New Job Entry")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Paste a URL to scrape the job description automatically, or paste the text directly below.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }

            // URL + Scrape row
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    TextField("Job posting URL (optional)", text: $jobURL)
                        .textFieldStyle(.roundedBorder)

                    if isScraping {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(width: 80)
                    } else {
                        Button("Fetch from URL") {
                            fetchURL()
                        }
                        .disabled(jobURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                if let error = scrapeError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            TextEditor(text: $pastedText)
                .font(.body)
                .frame(minHeight: 200)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Analyze with AI") {
                    submitJob()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(pastedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isScraping)
            }
        }
        .padding(24)
        .frame(minWidth: 560, minHeight: 420)
    }

    private func fetchURL() {
        let url = jobURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty else { return }

        isScraping = true
        scrapeError = nil

        Task {
            do {
                pastedText = try await PageFetcher.fetchPageText(url: url)
            } catch {
                scrapeError = error.localizedDescription
            }
            isScraping = false
        }
    }

    private func submitJob() {
        let trimmed = pastedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let entry = JobEntry(rawJobDescription: trimmed)
        let url = jobURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !url.isEmpty { entry.jobURL = url }

        modelContext.insert(entry)
        try? modelContext.save()

        let entryID = entry.id
        dismiss()

        Task.detached {
            await JobAnalysisCoordinator.analyze(entryID: entryID)
        }
    }
}

#Preview {
    NewJobSheet()
        .modelContainer(ModelContainer.preview)
}
