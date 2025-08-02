//
//  InspectorPanelView.swift
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

struct InspectorPanelView: View {
    let imageStack: ImageStack
    let stackRunner: FocusStackRunner
    let stackedResult: MLXImage?
    
    var body: some View {
        VStack {
            if stackRunner.isRunning, let progressiveFocusMap = stackRunner.progressiveFocusMap {
                // Display the progressive focus map while running
                #if os(macOS)
                let cgImage = progressiveFocusMap.asCGImage()
                let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                ZoomableImageView(image: nsImage)
                #else
                let cgImage = progressiveFocusMap.asCGImage()
                let uiImage = UIImage(cgImage: cgImage)
                ZoomableImageView(image: uiImage)
                #endif
            } else if let stackedResult = stackedResult {
                // Display the stacked result
                #if os(macOS)
                let cgImage = stackedResult.asCGImage()
                let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                ZoomableImageView(image: nsImage)
                #else
                let cgImage = stackedResult.asCGImage()
                let uiImage = UIImage(cgImage: cgImage)
                ZoomableImageView(image: uiImage)
                #endif
            } else {
                // Show placeholder when no stacked result
                VStack(spacing: 16) {
                    Image(systemName: "photo.stack.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text(stackRunner.isRunning ? "Building focus map..." : "Stacked result will appear here")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            if stackRunner.isRunning {
                VStack {
                    ProgressView(value: stackRunner.progress)
                        .progressViewStyle(LinearProgressViewStyle())
                    Text("\(Int(stackRunner.progress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
        }
    }
}

#Preview {
    InspectorPanelView(imageStack: ImageStack(timestamp: Date()), stackRunner: FocusStackRunner(), stackedResult: nil)
}