//
//  ZoomableImageView.swift
//  RyFocus
//
//  Created by Ryan Mitts on 2025-08-01.
//

import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct ZoomableImageView: View {
    #if os(macOS)
    let image: NSImage
    #else
    let image: UIImage
    #endif
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var dragOffset: CGSize = .zero
    @State private var fitScale: CGFloat = 1.0
    @State private var isDragging = false
    
    private var actualZoom: Int {
        Int((scale * fitScale) * 100)
    }
    
    private func calculateFitScale(geometry: GeometryProxy) {
        let imageSize = image.size
        let viewSize = geometry.size
        
        let widthScale = viewSize.width / imageSize.width
        let heightScale = viewSize.height / imageSize.height
        
        fitScale = min(widthScale, heightScale)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Zoom controls toolbar
            HStack {
                Button(action: {
                    withAnimation(.spring()) {
                        scale = max(scale * 0.8, 0.5)
                    }
                }) {
                    Image(systemName: "minus.magnifyingglass")
                }
                .buttonStyle(.borderless)
                
                Text("\(actualZoom)%")
                    .frame(width: 60)
                    .font(.system(.body, design: .monospaced))
                
                Button(action: {
                    withAnimation(.spring()) {
                        scale = min(scale * 1.25, 20.0)
                    }
                }) {
                    Image(systemName: "plus.magnifyingglass")
                }
                .buttonStyle(.borderless)
                
                Divider()
                    .frame(height: 20)
                    .padding(.horizontal, 8)
                
                Button(action: {
                    withAnimation(.spring()) {
                        scale = 1.0 / fitScale
                        offset = .zero
                        dragOffset = .zero
                    }
                }) {
                    Text("100%")
                }
                .buttonStyle(.borderless)
                
                Button("Fit") {
                    withAnimation(.spring()) {
                        scale = 1.0
                        offset = .zero
                        dragOffset = .zero
                    }
                }
                .buttonStyle(.borderless)
                
                Spacer()
            }
            .padding(8)
            .zIndex(1)
            
            Divider()
            
            // Image view
            GeometryReader { geometry in
                ZStack {
                    #if os(macOS)
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .offset(x: offset.width + dragOffset.width, y: offset.height + dragOffset.height)
                        .onAppear {
                            calculateFitScale(geometry: geometry)
                        }
                        .onChange(of: geometry.size) {
                            calculateFitScale(geometry: geometry)
                        }
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = value
                                }
                                .onEnded { value in
                                    withAnimation(.spring()) {
                                        scale = min(max(value, 0.5), 20.0)
                                    }
                                }
                        )
                        .simultaneousGesture(
                            DragGesture()
                                .onChanged { value in
                                    dragOffset = value.translation
                                }
                                .onEnded { value in
                                    offset.width += value.translation.width
                                    offset.height += value.translation.height
                                    dragOffset = .zero
                                }
                        )
                        .onTapGesture(count: 2) {
                            withAnimation(.spring()) {
                                scale = 1.0
                                offset = .zero
                                dragOffset = .zero
                            }
                        }
                    #else
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .offset(x: offset.width + dragOffset.width, y: offset.height + dragOffset.height)
                        .onAppear {
                            calculateFitScale(geometry: geometry)
                        }
                        .onChange(of: geometry.size) {
                            calculateFitScale(geometry: geometry)
                        }
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = value
                                }
                                .onEnded { value in
                                    withAnimation(.spring()) {
                                        scale = min(max(value, 0.5), 20.0)
                                    }
                                }
                        )
                        .simultaneousGesture(
                            DragGesture()
                                .onChanged { value in
                                    dragOffset = value.translation
                                }
                                .onEnded { value in
                                    offset.width += value.translation.width
                                    offset.height += value.translation.height
                                    dragOffset = .zero
                                }
                        )
                        .onTapGesture(count: 2) {
                            withAnimation(.spring()) {
                                scale = 1.0
                                offset = .zero
                                dragOffset = .zero
                            }
                        }
                    #endif
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}