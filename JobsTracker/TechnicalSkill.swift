//
//  TechnicalSkill.swift
//  JobsTracker
//
//  Created by Marcos Leal on 3/2/26.
//

import Foundation
import SwiftData

@Model
final class TechnicalSkill {
    var id: UUID
    var name: String
    var isKnown: Bool
    var entry: JobEntry?

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.isKnown = false
    }
}
