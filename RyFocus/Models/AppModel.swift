//
//  AppModel.swift
//  RyFocus
//
//  Created by Ryan Mitts on 2025-08-02.
//

import Foundation
import SwiftUI

@Observable @MainActor
class AppModel {
    var windowSize: CGSize = .zero

    var selectedImageStack: ImageStack? = nil {
        didSet {
            // Open inspector when an item is selected, close when deselected
            if selectedImageStack != nil && oldValue == nil {
                isInspectorPresented = true
            } else if selectedImageStack == nil {
                isInspectorPresented = false
            }
        }
    }
    var isInspectorPresented: Bool = false
    
    init() {
        // Initialize any other app-wide state here
    }
}
