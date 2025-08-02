//
//  ImageLoadErrorView.swift
//  RyFocus
//
//  Created by Ryan Mitts on 2025-08-02.
//

import SwiftUI

struct ImageLoadErrorView: View {
    let url: URL

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text("Unable to load image")
                .font(.headline)
            Text(url.lastPathComponent)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    ImageLoadErrorView(url: URL(fileURLWithPath: "/path/to/example.jpg"))
}