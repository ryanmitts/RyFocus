//
//  ImageStackInspectorView.swift
//  RyFocus
//
//  Created by Ryan Mitts on 2025-08-02.
//

import SwiftUI

struct ImageStackInspectorView: View {
    let imageStack: ImageStack
    @Binding var inspectorIsPresented: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Details")
                    .font(.headline)
                Spacer()
                Button {
                    inspectorIsPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                Label("Created", systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(imageStack.timestamp, format: Date.FormatStyle(date: .abbreviated, time: .shortened))
                    .font(.body)
            }
            .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 8) {
                Label("Images", systemImage: "photo.stack")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(imageStack.imageUrls.count) images")
                    .font(.body)
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .inspectorColumnWidth(min: 200, ideal: 250, max: 300)
    }
}

#Preview {
    ImageStackInspectorView(
        imageStack: ImageStack(timestamp: Date()),
        inspectorIsPresented: .constant(true)
    )
}