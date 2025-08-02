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
    @Query private var imageStacks: [ImageStack]
    @State private var selection: ImageStack.ID?

    var body: some View {
        NavigationSplitView {
            List(imageStacks, selection: $selection) { stack in
                Text(stack.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .onDeleteCommand {
                deleteSelected()
            }
#if os(macOS)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
#endif
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
#endif
                ToolbarItem {
                    Button(action: addItem) {
                        Label("Add Item", systemImage: "plus")
                    }
                }
#if os(macOS)
                ToolbarItem {
                    Button(action: deleteSelected) {
                        Label("Delete", systemImage: "trash")
                    }
                    .disabled(selection == nil || !imageStacks.contains(where: { $0.id == selection }))
                }
#endif
            }
        } detail: {
            if let selection = selection,
               let stack = imageStacks.first(where: { $0.id == selection }) {
                Text("Item at \(stack.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))")
            } else {
                Text("Select an item")
            }
        }
    }

    private func addItem() {
        withAnimation {
            let newItem = ImageStack(timestamp: Date())
            modelContext.insert(newItem)
        }
    }

    private func deleteSelected() {
        withAnimation {
            if let selection = selection,
               let stack = imageStacks.first(where: { $0.id == selection }) {
                modelContext.delete(stack)
                // Force selection update to avoid the double-click issue
                DispatchQueue.main.async {
                    self.selection = nil
                }
            }
        }
    }
    
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(imageStacks[index])
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: ImageStack.self, inMemory: true)
}
