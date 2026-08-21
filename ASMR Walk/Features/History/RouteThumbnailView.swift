//
//  RouteThumbnailView.swift
//  ASMR Walk
//

import SwiftUI
import UIKit

struct RouteThumbnailView: View {
    let recording: WalkRecording
    let size: CGSize

    var body: some View {
        Group {
            if let image = thumbnailImage {
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
    }

    private var thumbnailImage: UIImage? {
        guard let thumbnailURL = recording.thumbnailURL else {
            return nil
        }

        return UIImage(contentsOfFile: thumbnailURL.path)
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
