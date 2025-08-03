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
    let stackActor: FocusStackActor
    let stackedResult: CGImage?
    let progress: Progress?

    var body: some View {
        VStack {
            if let progress = progress, progress.isRunning,
               let progressiveFocusMap = progress.image
            {
                // Display the progressive focus map while running
                #if os(macOS)
                    let nsImage = NSImage(
                        cgImage: progressiveFocusMap,
                        size: NSSize(
                            width: progressiveFocusMap.width,
                            height: progressiveFocusMap.height
                        )
                    )
                    ZoomableImageView(image: nsImage)
                #else
                    let uiImage = UIImage(cgImage: progressiveFocusMap)
                    ZoomableImageView(image: uiImage)
                #endif
            } else if let stackedResult = stackedResult {
                // Display the stacked result
                #if os(macOS)
                    let nsImage = NSImage(
                        cgImage: stackedResult,
                        size: NSSize(
                            width: stackedResult.width,
                            height: stackedResult.height
                        )
                    )
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
                    Text(
                        progress?.isRunning == true
                            ? "Building focus map..."
                            : "Stacked result will appear here"
                    )
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if let progress = progress, progress.isRunning,
                let current = progress.current,
                let limit = progress.limit, limit > 0
            {
                let fraction = current / limit

                VStack {
                    ProgressView(value: fraction)
                        .progressViewStyle(LinearProgressViewStyle())
                    Text("\(Int(fraction * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
        }
    }
}

#Preview {
    InspectorPanelView(
        imageStack: ImageStack(timestamp: Date()),
        stackActor: FocusStackActor.shared,
        stackedResult: nil,
        progress: nil
    )
}
