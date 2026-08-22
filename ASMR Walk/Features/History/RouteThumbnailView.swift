//
//  RouteThumbnailView.swift
//  ASMR Walk
//

import SwiftUI
import UIKit

struct RouteThumbnailView: View {
    let recording: WalkRecording
    let size: CGSize

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                fallback
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(.rect(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.primary.opacity(0.12), lineWidth: 1)
        }
        .accessibilityHidden(true)
        .task(id: recording.thumbnailURL) {
            guard let url = recording.thumbnailURL else {
                image = nil
                return
            }
            let path = url.path
            image = await Task.detached(priority: .utility) {
                UIImage(contentsOfFile: path)
            }.value
        }
    }

    private var fallback: some View {
        ZStack {
            Rectangle()
                .fill(.quaternary)

            Image(systemName: recording.mode.systemImage)
                .font(.title2)
                .foregroundStyle(recording.hasVideo ? .red : .green)
        }
    }
}
