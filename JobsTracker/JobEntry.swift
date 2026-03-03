//
//  JobEntry.swift
//  JobsTracker
//
//  Created by Marcos Leal on 3/2/26.
//

import Foundation
import SwiftData

@Model
final class JobEntry {
    var id: UUID
    var createdAt: Date
    var rawJobDescription: String
    var statusRaw: String
    var errorMessage: String?

    // Extracted company info
    var companyName: String?
    var companyAddress: String?
    var companyWebsite: String?
    var jobPosition: String?

    @Relationship(deleteRule: .cascade, inverse: \TechnicalSkill.entry)
    var skills: [TechnicalSkill] = []

    // Computed helpers — not persisted
    var status: AnalysisStatus {
        get { AnalysisStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    var allSkillsKnown: Bool {
        !skills.isEmpty && skills.allSatisfy(\.isKnown)
    }

    init(rawJobDescription: String) {
        self.id = UUID()
        self.createdAt = Date()
        self.rawJobDescription = rawJobDescription
        self.statusRaw = AnalysisStatus.pending.rawValue
    }
}
