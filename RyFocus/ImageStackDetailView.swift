//
//  ImageStackDetailView.swift
//  RyFocus
//
//  Created by Ryan Mitts on 2025-08-02.
//

import SwiftUI

#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

struct ImageStackDetailView: View {
    let imageStack: ImageStack
    @Binding var isInspectorPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            if let selectedURL = imageStack.selectedImageURL {
                // Display the selected image with zoom and pan capabilities
                #if os(macOS)
                    if let nsImage = imageStack.withSecurityScopedAccess(
                        to: selectedURL
                    ) { url in
                        NSImage(contentsOf: url)
                    } {
                        ZoomableImageView(image: nsImage)
                    } else {
                        ImageLoadErrorView(url: selectedURL)
                    }
                #else
                    if let uiImage = imageStack.withSecurityScopedAccess(
                        to: selectedURL
                    ) { url in
                        guard let data = try? Data(contentsOf: url) else {
                            return nil
                        }
                        return UIImage(data: data)
                    } {
                        ZoomableImageView(image: uiImage)
                    } else {
                        ImageLoadErrorView(url: selectedURL)
                    }
                #endif
            } else if !imageStack.imageUrls.isEmpty {
                // Show prompt to select an image
                VStack(spacing: 16) {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Select an image from the inspector")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // No images available
                VStack(spacing: 16) {
                    Image(systemName: "photo.stack")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No images in stack")
                        .foregroundStyle(.secondary)
                    Text(
                        "Item at \(imageStack.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))"
                    )
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

struct ImageLoadErrorView: View {
    let url: URL

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text("Unable to load image")
                .font(.headline)
            Text(url.lastPathComponent)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    ImageStackDetailView(
        imageStack: ImageStack(timestamp: Date()),
        isInspectorPresented: .constant(false)
    )
}
