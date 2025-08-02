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
    var selectedImageStack: ImageStack? = nil
    var isInspectorPresented: Bool = false
    
    init() {
        // Initialize any other app-wide state here
    }
}