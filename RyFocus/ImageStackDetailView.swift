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
        VStack {
            Text("Item at \(imageStack.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))")
                .font(.title2)
                .padding()
            
            Spacer()
            
            // Placeholder for future content like image grid
            Text("Images will be displayed here")
                .foregroundStyle(.secondary)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Image Stack")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isInspectorPresented.toggle()
                } label: {
                    Label("Toggle Inspector", systemImage: "sidebar.right")
                }
            }
        }
    }
}

#Preview {
    ImageStackDetailView(
        imageStack: ImageStack(timestamp: Date()),
        isInspectorPresented: .constant(false)
    )
}