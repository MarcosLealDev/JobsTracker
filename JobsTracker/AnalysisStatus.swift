//
//  AnalysisStatus.swift
//  JobsTracker
//
//  Created by Marcos Leal on 3/2/26.
//

import Foundation

enum AnalysisStatus: String, Codable {
    case pending    // Inserted, waiting for analysis
    case analyzing  // Network request in-flight
    case done       // Analysis completed successfully
    case failed     // Analysis failed; errorMessage is populated
}
