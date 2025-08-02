//
//  AppModel.swift
//  RyFocus
//
//  Created by Ryan Mitts on 2025-08-02.
//

import Foundation
import SwiftUI
import SwiftData

@Observable @MainActor
class AppModel {
    var imageStacks: [ImageStack] = []
    var selectedImageStack: ImageStack? = nil
    var isInspectorPresented: Bool = false
    
    private var modelContext: ModelContext?
    
    init() {
        // Model context will be set after initialization
    }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        loadImageStacks()
        
        // Listen for SwiftData changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(contextDidChange),
            name: .NSManagedObjectContextObjectsDidChange,
            object: context
        )
    }
    
    @objc private func contextDidChange(_ notification: Notification) {
        Task { @MainActor in
            loadImageStacks()
        }
    }
    
    func loadImageStacks() {
        guard let modelContext = modelContext else { return }
        
        let descriptor = FetchDescriptor<ImageStack>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        
        do {
            imageStacks = try modelContext.fetch(descriptor)
        } catch {
            print("Failed to fetch image stacks: \(error)")
            imageStacks = []
        }
    }
    
    func addImageStack() {
        guard let modelContext = modelContext else { return }
        
        withAnimation {
            let newStack = ImageStack(timestamp: Date())
            modelContext.insert(newStack)
        }
    }
    
    func deleteImageStack(_ stack: ImageStack) {
        guard let modelContext = modelContext else { return }
        
        withAnimation {
            modelContext.delete(stack)
            if selectedImageStack == stack {
                selectedImageStack = nil
            }
        }
    }
    
    func deleteSelected() {
        if let selected = selectedImageStack {
            deleteImageStack(selected)
        }
    }
}