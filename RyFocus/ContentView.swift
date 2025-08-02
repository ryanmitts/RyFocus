//
//  ContentView.swift
//  RyFocus
//
//  Created by Ryan Mitts on 2025-08-01.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        @Bindable var appModel = appModel
        
        NavigationSplitView {
            List(selection: Binding(
                get: { appModel.selectedImageStack?.id },
                set: { newValue in
                    appModel.selectedImageStack = appModel.imageStacks.first { $0.id == newValue }
                }
            )) {
                ForEach(appModel.imageStacks) { stack in
                    Text(stack.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        appModel.deleteImageStack(appModel.imageStacks[index])
                    }
                }
            }
            .onDeleteCommand {
                appModel.deleteSelected()
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
                    Button(action: appModel.addImageStack) {
                        Label("Add Item", systemImage: "plus")
                    }
                }
#if os(macOS)
                ToolbarItem {
                    Button(action: appModel.deleteSelected) {
                        Label("Delete", systemImage: "trash")
                    }
                    .disabled(appModel.selectedImageStack == nil)
                }
#endif
            }
        } detail: {
            if let stack = appModel.selectedImageStack {
                Text("Item at \(stack.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Button {
                                appModel.isInspectorPresented.toggle()
                            } label: {
                                Label("Toggle Inspector", systemImage: "sidebar.right")
                            }
                        }
                    }
                    .inspector(isPresented: $appModel.isInspectorPresented) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Details")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            Divider()
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Created", systemImage: "calendar")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(stack.timestamp, format: Date.FormatStyle(date: .abbreviated, time: .shortened))
                                    .font(.body)
                            }
                            .padding(.horizontal)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Images", systemImage: "photo.stack")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("\(stack.imageUrls.count) images")
                                    .font(.body)
                            }
                            .padding(.horizontal)
                            
                            Spacer()
                        }
                        .inspectorColumnWidth(min: 200, ideal: 250, max: 300)
                    }
            } else {
                Text("Select an item")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

}

#Preview {
    ContentView()
        .modelContainer(for: ImageStack.self, inMemory: true)
        .environment(AppModel())
}
