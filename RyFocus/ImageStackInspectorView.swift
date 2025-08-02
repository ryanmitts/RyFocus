//
//  ImageStackInspectorView.swift
//  RyFocus
//
//  Created by Ryan Mitts on 2025-08-02.
//

import SwiftUI
import UniformTypeIdentifiers
import CoreImage
import SwiftData

struct ImageStackInspectorView: View {
    let imageStack: ImageStack
    @Binding var inspectorIsPresented: Bool
    @Environment(\.modelContext) private var modelContext
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
            
            if imageStack.imageUrls.isEmpty {
                // Drop area when no images
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
            } else {
                // List view when images exist
                List(selection: Binding(
                    get: { imageStack.selectedImageURL },
                    set: { newValue in
                        imageStack.selectedImageURL = newValue
                        do {
                            try modelContext.save()
                        } catch {
                            print("Failed to save selected image: \(error)")
                        }
                    }
                )) {
                    ForEach(Array(imageStack.imageUrls.enumerated()), id: \.element) { index, url in
                        HStack {
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(url.lastPathComponent)
                                    .font(.body)
                                    .lineLimit(1)
                                
                                Text(url.pathExtension.uppercased())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 2)
                        .tag(url)
                    }
                    .onDelete(perform: removeImages)
                }
                .listStyle(.plain)
                .onDrop(of: supportedImageTypes, isTargeted: $isTargeted) { providers in
                    handleDrop(providers: providers)
                }
                .background(isTargeted ? Color.blue.opacity(0.1) : Color.clear)
                
                // Clear all button
                VStack {
                    Divider()
                    Button(action: clearAllImages) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Clear All Images")
                        }
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .background(Color(NSColor.controlBackgroundColor))
            }
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: supportedImageTypes,
            allowsMultipleSelection: true
        ) { result in
            handleFileSelection(result: result)
        }
        .inspectorColumnWidth(min: 250, ideal: 250, max: 350)
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        print("Processing \(providers.count) dropped items")
        
        for (index, provider) in providers.enumerated() {
            // Use loadInPlaceFileRepresentation to get the original file URL
            provider.loadInPlaceFileRepresentation(forTypeIdentifier: UTType.item.identifier) { url, inPlace, error in
                if let error = error {
                    print("Error loading item \(index): \(error)")
                    
                    // Fallback to regular file representation
                    provider.loadFileRepresentation(forTypeIdentifier: UTType.item.identifier) { fallbackUrl, fallbackError in
                        if let fallbackUrl = fallbackUrl {
                            DispatchQueue.main.async {
                                self.addImageUrl(fallbackUrl)
                            }
                        } else if let fallbackError = fallbackError {
                            print("Fallback error for item \(index): \(fallbackError)")
                        }
                    }
                    return
                }
                
                if let url = url {
                    print("Got URL for item \(index): \(url.path), inPlace: \(inPlace)")
                    DispatchQueue.main.async {
                        self.addImageUrl(url)
                    }
                }
            }
        }
        
        return true
    }
    
    private func handleFileSelection(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            for url in urls {
                addImageUrl(url)
            }
        case .failure(let error):
            print("File selection error: \(error)")
        }
    }
    
    private func addImageUrl(_ url: URL) {
        // Check if file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("File does not exist: \(url.path)")
            return
        }
        
        // Start accessing the security-scoped resource
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        do {
            // Create bookmark for persistent access
            let bookmarkData = try url.bookmarkData(
                options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            
            // Store the bookmark data
            imageStack.imageBookmarks.append(bookmarkData)
            try modelContext.save()
            print("Added image: \(url.lastPathComponent)")
            
        } catch {
            print("Failed to create bookmark: \(error)")
        }
    }
    
    private func removeImages(at offsets: IndexSet) {
        let urlsToRemove = offsets.map { imageStack.imageUrls[$0] }
        
        for index in offsets.sorted(by: >) {
            imageStack.imageBookmarks.remove(at: index)
        }
        
        // Clear selection if the removed image was selected
        if let selectedURL = imageStack.selectedImageURL,
           urlsToRemove.contains(where: { $0.path == selectedURL.path }) {
            imageStack.selectedImageURL = nil
        }
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to save context: \(error)")
        }
    }
    
    private func clearAllImages() {
        imageStack.imageBookmarks.removeAll()
        imageStack.selectedImageURL = nil
        
        do {
            try modelContext.save()
            print("Cleared all images from stack")
        } catch {
            print("Failed to save context: \(error)")
        }
    }
}

#Preview {
    ImageStackInspectorView(
        imageStack: ImageStack(timestamp: Date()),
        inspectorIsPresented: .constant(true)
    )
}
