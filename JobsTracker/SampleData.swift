//
//  SampleData.swift
//  JobsTracker
//
//  Created by Marcos Leal on 3/2/26.
//

import Foundation
import SwiftData

// MARK: - Preview Container

extension ModelContainer {
    /// In-memory container pre-populated with sample job entries for SwiftUI previews.
    @MainActor
    static var preview: ModelContainer {
        let schema = Schema([JobEntry.self, TechnicalSkill.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])
        SampleData.insertAll(into: container.mainContext)
        return container
    }
}

// MARK: - Sample Data

enum SampleData {

    @MainActor
    static func insertAll(into context: ModelContext) {
        for entry in makeSampleEntries() {
            context.insert(entry)
        }
        try? context.save()
    }

    private static func makeSampleEntries() -> [JobEntry] {

        // Entry A: All skills known → star badge visible in list
        let entryA = JobEntry(rawJobDescription: appleJobDescription)
        entryA.createdAt = Date().addingTimeInterval(-86400 * 3)
        entryA.status = .done
        entryA.companyName    = "Apple Inc."
        entryA.companyAddress = "One Apple Park Way, Cupertino, CA 95014"
        entryA.companyWebsite = "https://www.apple.com"
        entryA.jobPosition    = "Senior iOS Engineer"
        let appleSkills = ["Swift", "SwiftUI", "SwiftData", "Xcode", "Core Data"]
        appleSkills.forEach { name in
            let s = TechnicalSkill(name: name)
            s.isKnown = true
            s.entry = entryA
            entryA.skills.append(s)
        }

        // Entry B: Mixed skills — partial progress, no star
        let entryB = JobEntry(rawJobDescription: stripeJobDescription)
        entryB.createdAt = Date().addingTimeInterval(-86400 * 2)
        entryB.status = .done
        entryB.companyName    = "Stripe"
        entryB.companyAddress = "510 Townsend St, San Francisco, CA 94103"
        entryB.companyWebsite = "https://stripe.com"
        entryB.jobPosition    = "Backend Engineer"
        let stripeSkillData: [(String, Bool)] = [
            ("Go", true), ("PostgreSQL", true), ("Kubernetes", false),
            ("gRPC", false), ("Redis", true), ("Docker", false)
        ]
        stripeSkillData.forEach { name, known in
            let s = TechnicalSkill(name: name)
            s.isKnown = known
            s.entry = entryB
            entryB.skills.append(s)
        }

        // Entry C: Analysis failed — shows error state in detail
        let entryC = JobEntry(rawJobDescription: openAIJobDescription)
        entryC.createdAt = Date().addingTimeInterval(-86400)
        entryC.status = .failed
        entryC.errorMessage = "Ollama returned HTTP 404. Is Ollama running on port 11434?"

        // Entry D: Still analyzing — shows spinner in list and detail
        let entryD = JobEntry(rawJobDescription: vercelJobDescription)
        entryD.createdAt = Date().addingTimeInterval(-3600)
        entryD.status = .analyzing

        return [entryA, entryB, entryC, entryD]
    }

    // MARK: - Raw Descriptions

    private static let appleJobDescription = """
    Senior iOS Engineer — Apple Inc.
    Location: One Apple Park Way, Cupertino, CA 95014
    Website: https://www.apple.com

    We are looking for a Senior iOS Engineer to join the Platform Architecture team.
    You will design and implement high-impact features used by millions of users.

    Requirements:
    • 5+ years of iOS development experience
    • Deep expertise in Swift and SwiftUI
    • Experience with SwiftData or Core Data
    • Proficiency with Xcode and Instruments
    • Strong understanding of Apple's Human Interface Guidelines
    """

    private static let stripeJobDescription = """
    Backend Engineer — Stripe
    Location: 510 Townsend St, San Francisco, CA 94103
    Website: https://stripe.com

    Join Stripe's Payments Infrastructure team to build the financial infrastructure of the internet.

    Requirements:
    • Experience with Go programming language
    • Strong SQL skills, preferably PostgreSQL
    • Familiarity with Kubernetes and container orchestration
    • Experience with gRPC and microservices
    • Knowledge of Redis caching strategies
    • Docker for local development
    """

    private static let openAIJobDescription = """
    Machine Learning Engineer — OpenAI
    Location: 3180 18th St, San Francisco, CA 94110
    Website: https://openai.com

    Work on cutting-edge AI systems that push the frontier of what's possible.

    Requirements:
    • PhD or equivalent research experience in Machine Learning
    • Python, PyTorch, JAX
    • Large-scale distributed training
    • CUDA and GPU optimization
    """

    private static let vercelJobDescription = """
    Full Stack Developer — Vercel
    Location: Remote
    Website: https://vercel.com

    Build the future of web development infrastructure.

    Requirements:
    • React and Next.js expertise
    • TypeScript
    • Node.js backend development
    • Edge computing and CDN experience
    • REST and GraphQL API design
    """
}
