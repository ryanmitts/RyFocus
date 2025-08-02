//
//  ContentView.swift
//  RyFocus
//
//  Created by Ryan Mitts on 2025-08-01.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppModel.self) private var appModel
    @Query(sort: \ImageStack.timestamp, order: .reverse) private var imageStacks: [ImageStack]
    @State private var preferredColumn: NavigationSplitViewColumn = .detail

    var body: some View {
        @Bindable var appModel = appModel
        
        NavigationSplitView(preferredCompactColumn: $preferredColumn) {
            List(selection: Binding(
                get: { appModel.selectedImageStack?.id },
                set: { newValue in
                    appModel.selectedImageStack = imageStacks.first { $0.id == newValue }
                }
            )) {
                ForEach(imageStacks) { stack in
                    Text(stack.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        deleteImageStack(imageStacks[index])
                    }
                }
            }
#if os(macOS)
            .onDeleteCommand {
                deleteSelected()
            }
#endif
#if os(macOS)
            .navigationSplitViewColumnWidth(min: 250, ideal: 250)
#endif
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
#endif
                ToolbarItem {
                    Button {
                        addImageStack()
                    } label: {
                        Label("Add Item", systemImage: "plus")
                    }
                }
#if os(macOS)
                ToolbarItem {
                    Button {
                        deleteSelected()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .disabled(appModel.selectedImageStack == nil)
                }
#endif
            }
        } detail: {
            if let stack = appModel.selectedImageStack {
                ImageStackDetailView(
                    imageStack: stack,
                    isInspectorPresented: $appModel.isInspectorPresented
                )
            } else {
                EmptySelectionView()
            }
        }
        .inspector(isPresented: $appModel.isInspectorPresented) {
            if let stack = appModel.selectedImageStack {
                ImageStackInspectorView(
                    imageStack: stack,
                    inspectorIsPresented: $appModel.isInspectorPresented
                )
            } else {
                EmptyView()
            }
        }
    }
    
    private func addImageStack() {
        withAnimation {
            let newStack = ImageStack(timestamp: Date())
            modelContext.insert(newStack)
        }
    }
    
    private func deleteImageStack(_ stack: ImageStack) {
        withAnimation {
            modelContext.delete(stack)
            if appModel.selectedImageStack == stack {
                appModel.selectedImageStack = nil
            }
        }
    }
    
    private func deleteSelected() {
        if let selected = appModel.selectedImageStack {
            deleteImageStack(selected)
        }
    }

}

#Preview {
    ContentView()
        .modelContainer(for: ImageStack.self, inMemory: true)
        .environment(AppModel())
}
