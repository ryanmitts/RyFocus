//
//  EmptySelectionView.swift
//  RyFocus
//
//  Created by Ryan Mitts on 2025-08-02.
//

import SwiftUI

struct EmptySelectionView: View {
    var body: some View {
        Image(decorative: "BackgroundCover")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .ignoresSafeArea(.all)
            .backgroundExtensionEffect()

        //        VStack(spacing: 20) {
        //            Image(systemName: "photo.stack")
        //                .font(.system(size: 60))
        //                .foregroundStyle(.secondary)
        //
        //            Text("Select an Image Stack")
        //                .font(.title2)
        //                .fontWeight(.medium)
        //
        //            Text("Choose an image stack from the sidebar to view its contents")
        //                .font(.body)
        //                .foregroundStyle(.secondary)
        //                .multilineTextAlignment(.center)
        //                .padding(.horizontal)
        //        }
        //        .frame(maxWidth: .infinity, maxHeight: .infinity)
        //        .background(Color(NSColor.controlBackgroundColor))
    }
}

#Preview {
    EmptySelectionView()
}
