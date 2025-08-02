//
//  Item.swift
//  RyFocus
//
//  Created by Ryan Mitts on 2025-08-01.
//

import Foundation
import SwiftData

@Model
final class ImageStack {
    var timestamp: Date
    var imageBookmarks: [Data]
    var selectedImageBookmark: Data?
    
    init(timestamp: Date) {
        self.timestamp = timestamp
        self.imageBookmarks = []
        self.selectedImageBookmark = nil
    }
    
    // Computed property to resolve URLs from bookmarks
    var imageUrls: [URL] {
        return imageBookmarks.compactMap { bookmarkData in
            do {
                var isStale = false
                let url = try URL(resolvingBookmarkData: bookmarkData, 
                                options: [.withSecurityScope], 
                                relativeTo: nil, 
                                bookmarkDataIsStale: &isStale)
                return url
            } catch {
                print("Failed to resolve bookmark: \(error)")
                return nil
            }
        }
    }
    
    // Helper method to safely access an image URL with security scope
    func withSecurityScopedAccess<T>(to url: URL, perform: (URL) -> T?) -> T? {
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return perform(url)
    }
    
    var selectedImageURL: URL? {
        get {
            guard let selectedBookmark = selectedImageBookmark else { return nil }
            do {
                var isStale = false
                return try URL(resolvingBookmarkData: selectedBookmark,
                             options: [.withSecurityScope],
                             relativeTo: nil,
                             bookmarkDataIsStale: &isStale)
            } catch {
                print("Failed to resolve selected bookmark: \(error)")
                return nil
            }
        }
        set {
            if let url = newValue {
                do {
                    let accessing = url.startAccessingSecurityScopedResource()
                    defer {
                        if accessing {
                            url.stopAccessingSecurityScopedResource()
                        }
                    }
                    
                    selectedImageBookmark = try url.bookmarkData(
                        options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                        includingResourceValuesForKeys: nil,
                        relativeTo: nil
                    )
                } catch {
                    print("Failed to create bookmark for selected image: \(error)")
                    selectedImageBookmark = nil
                }
            } else {
                selectedImageBookmark = nil
            }
        }
    }
}
