//
//  JobAnalysisCoordinator.swift
//  JobsTracker
//
//  Created by Marcos Leal on 3/2/26.
//

import Foundation
import SwiftData

/// Manages the full analysis lifecycle: pending → analyzing → done/failed.
/// @MainActor ensures ModelContext is accessed safely on the main thread.
/// The `await OllamaService.shared.analyze(...)` call suspends (not blocks)
/// the main actor while the network work runs on the cooperative thread pool.
enum JobAnalysisCoordinator {

    @MainActor
    static func analyze(entryID: UUID) async {
        let context = JobsTrackerApp.sharedModelContainer.mainContext

        var descriptor = FetchDescriptor<JobEntry>(
            predicate: #Predicate { $0.id == entryID }
        )
        descriptor.fetchLimit = 1

        guard let entry = try? context.fetch(descriptor).first else { return }

        // Clear previous results before re-analyzing
        for skill in entry.skills {
            context.delete(skill)
        }
        entry.skills.removeAll()
        entry.companyName = nil
        entry.companyAddress = nil
        entry.companyWebsite = nil
        entry.jobPosition = nil
        entry.errorMessage = nil

        entry.status = .analyzing
        try? context.save()

        do {
            let result = try await OllamaService.shared.analyze(
                jobDescription: entry.rawJobDescription
            )
            entry.companyName    = result.companyName
            entry.companyAddress = result.companyAddress
            entry.companyWebsite = result.companyWebsite
            entry.jobPosition    = result.jobPosition

            for skillName in result.technicalSkills where !skillName.trimmingCharacters(in: .whitespaces).isEmpty {
                let skill = TechnicalSkill(name: skillName)
                context.insert(skill)
                entry.skills.append(skill)
            }

            entry.status = .done
            entry.errorMessage = nil
        } catch {
            entry.status = .failed
            entry.errorMessage = error.localizedDescription
        }

        try? context.save()
    }
}
