//
//  ImageStackInspectorView.swift
//  RyFocus
//
//  Created by Ryan Mitts on 2025-08-02.
//

import SwiftUI
import UniformTypeIdentifiers
import CoreImage

struct ImageStackInspectorView: View {
    let imageStack: ImageStack
    @Binding var inspectorIsPresented: Bool
    @State private var isTargeted = false
    @State private var showingFilePicker = false
    
    // Supported image types that CoreImage can handle
    private let supportedImageTypes: [UTType] = [
        .jpeg,
        .png,
        .tiff,
        .gif,
        .bmp,
        .heic,
        .heif,
        .webP,
        .rawImage,
        // Common RAW formats
        UTType(filenameExtension: "cr2")!,  // Canon
        UTType(filenameExtension: "cr3")!,  // Canon
        UTType(filenameExtension: "nef")!,  // Nikon
        UTType(filenameExtension: "arw")!,  // Sony
        UTType(filenameExtension: "dng")!,  // Adobe DNG
        UTType(filenameExtension: "orf")!,  // Olympus
        UTType(filenameExtension: "raf")!,  // Fuji
        UTType(filenameExtension: "rw2")!,  // Panasonic
        UTType(filenameExtension: "pef")!,  // Pentax
        UTType(filenameExtension: "srw")!,  // Samsung
        UTType(filenameExtension: "x3f")!   // Sigma
    ].compactMap { $0 }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with title and add button
            HStack {
                Text("Images")
                    .font(.headline)
                Spacer()
                Button {
                    showingFilePicker = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            
            Divider()
            
            // Drop area
            VStack(spacing: 16) {
                Image(systemName: "photo.stack")
                    .font(.system(size: 40))
                    .foregroundStyle(isTargeted ? .blue : .secondary)
                
                Text("Drop images here")
                    .font(.body)
                    .foregroundStyle(isTargeted ? .blue : .secondary)
                
                Text("or click + to browse")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isTargeted ? Color.blue.opacity(0.1) : Color.clear)
                    .stroke(
                        isTargeted ? Color.blue : Color.secondary.opacity(0.3),
                        style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                    )
            )
            .padding()
            .onDrop(of: supportedImageTypes, isTargeted: $isTargeted) { providers in
                handleDrop(providers: providers)
            }
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: supportedImageTypes,
            allowsMultipleSelection: true
        ) { result in
            handleFileSelection(result: result)
        }
        .inspectorColumnWidth(min: 200, ideal: 280, max: 350)
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        print("Files dropped: \(providers.count) items")
        // TODO: Process dropped files and add to imageStack
        return true
    }
    
    private func handleFileSelection(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            print("Files selected: \(urls.count) items")
            // TODO: Process selected files and add to imageStack
        case .failure(let error):
            print("File selection error: \(error)")
        }
    }
}

#Preview {
    ImageStackInspectorView(
        imageStack: ImageStack(timestamp: Date()),
        inspectorIsPresented: .constant(true)
    )
}
