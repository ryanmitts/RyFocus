//
//  InspectorPanelView.swift
//  RyFocus
//
//  Created by Ryan Mitts on 2025-08-02.
//

import SwiftUI

struct InspectorPanelView: View {
    let imageStack: ImageStack
    
    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    InspectorPanelView(imageStack: ImageStack(timestamp: Date()))
}