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

    @State private var pastedText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("New Job Entry")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Paste the job description below. Ollama (llama3.1) will extract company info and required skills.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }

            TextEditor(text: $pastedText)
                .font(.body)
                .frame(minHeight: 220)
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
                .disabled(pastedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(minWidth: 520, minHeight: 380)
    }

    private func submitJob() {
        let trimmed = pastedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let entry = JobEntry(rawJobDescription: trimmed)
        modelContext.insert(entry)
        try? modelContext.save()

        let entryID = entry.id
        dismiss()

        // Detach from MainActor so the task isn't blocked by the actor,
        // then let the coordinator (which is @MainActor) hop back as needed.
        Task.detached {
            await JobAnalysisCoordinator.analyze(entryID: entryID)
        }
    }
}

#Preview {
    NewJobSheet()
        .modelContainer(ModelContainer.preview)
}
