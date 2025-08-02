//
//  Item.swift
//  RyFocus
//
//  Created by Ryan Mitts on 2025-08-01.
//

import Foundation
import SwiftData

@Model
final class ImageStack {
    var timestamp: Date
    var imageUrls: [URL]
    
    init(timestamp: Date) {
        self.timestamp = timestamp
        self.imageUrls = []
    }
}
