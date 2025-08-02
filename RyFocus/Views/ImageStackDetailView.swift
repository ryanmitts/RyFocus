//
//  ImageStackDetailView.swift
//  RyFocus
//
//  Created by Ryan Mitts on 2025-08-02.
//

import SwiftUI

struct ImageStackDetailView: View {
    let imageStack: ImageStack
    @Binding var isInspectorPresented: Bool

    var body: some View {
        #if os(macOS)
        HSplitView {
            ImageDisplayView(imageStack: imageStack)
            InspectorPanelView(imageStack: imageStack)
        }
        #else
        ImageDisplayView(imageStack: imageStack)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isInspectorPresented.toggle()
                    } label: {
                        Label("Toggle Inspector", systemImage: "sidebar.right")
                    }
                }
            }
        #endif
    }

}


#Preview {
    ImageStackDetailView(
        imageStack: ImageStack(timestamp: Date()),
        isInspectorPresented: .constant(false)
    )
}
