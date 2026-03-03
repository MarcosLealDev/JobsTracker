//
//  Item.swift
//  JobsTracker
//
//  Created by Marcos Leal on 3/2/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
