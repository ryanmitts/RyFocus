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
    @State private var stackRunner = FocusStackRunner()
    @State private var stackedResult: MLXImage?

    var body: some View {
        #if os(macOS)
        HSplitView {
            ImageDisplayView(imageStack: imageStack)
            InspectorPanelView(imageStack: imageStack, stackRunner: stackRunner, stackedResult: stackedResult)
        }
        .toolbar {
            ToolbarItemGroup(placement: .secondaryAction) {
                Button {
                    Task {
                        let urls = imageStack.imageUrls
                        stackedResult = try await stackRunner.stackWithSecurityScope(imageURLs: urls, debug: true)
                    }
                } label: {
                    Label("Stack Layers", systemImage: "square.3.layers.3d")
                }
                .disabled(stackRunner.isRunning || imageStack.imageUrls.isEmpty)
            }
            
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    isInspectorPresented.toggle()
                } label: {
                    Label("Toggle Inspector", systemImage: "sidebar.right")
                }
            }
        }
        #else
        ImageDisplayView(imageStack: imageStack)
            .toolbar {
                ToolbarItemGroup {
                    Button {
                        Task {
                            let urls = imageStack.imageUrls
                            stackedResult = try await stackRunner.stackWithSecurityScope(imageURLs: urls, debug: true)
                        }
                    } label: {
                        Label("Stack Layers", systemImage: "square.3.layers.3d")
                    }
                    .disabled(stackRunner.isRunning || imageStack.imageUrls.isEmpty)
                }
                
                ToolbarItemGroup(placement: .primaryAction) {
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
