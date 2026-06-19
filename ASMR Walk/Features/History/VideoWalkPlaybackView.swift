//
//  VideoWalkPlaybackView.swift
//  ASMR Walk
//

import AVFoundation
import AVKit
import SwiftUI

struct VideoWalkPlaybackView: View {
    let recording: WalkRecording

    @State private var player: AVPlayer?
    @State private var timeObserver: Any?
    @State private var currentTime: TimeInterval = 0

    var body: some View {
        Group {
            if let videoURL = recording.videoURL,
               FileManager.default.fileExists(atPath: videoURL.path) {
                ZStack(alignment: .topTrailing) {
                    if let player {
                        VideoPlayer(player: player)
                            .background(.black)
                    } else {
                        ProgressView("Loading Video")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(.black)
                            .foregroundStyle(.white)
                    }

                    RoutePlaybackMapView(recording: recording, elapsedTime: currentTime)
                        .frame(width: 170, height: 125)
                        .clipShape(.rect(cornerRadius: 18))
                        .glassEffect(.regular, in: .rect(cornerRadius: 18))
                        .padding(12)
                        .accessibilityIdentifier(AccessibilityID.videoRouteOverlay)
                }
                .task(id: videoURL) {
                    configurePlayer(for: videoURL)
                }
            } else {
                ContentUnavailableView(
                    "Video Unavailable",
                    systemImage: "video.slash",
                    description: Text("The video file for this walk could not be found.")
                )
            }
        }
        .onDisappear {
            player?.pause()
            removeTimeObserver()
        }
        .accessibilityIdentifier(AccessibilityID.videoPlayback)
    }

    private func configurePlayer(for url: URL) {
        removeTimeObserver()

        let player = AVPlayer(url: url)
        self.player = player
        currentTime = 0

        let interval = CMTime(value: 1, timescale: 2)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            currentTime = time.seconds.isFinite ? time.seconds : 0
        }
    }

    private func removeTimeObserver() {
        guard let timeObserver else {
            return
        }

        player?.removeTimeObserver(timeObserver)
        self.timeObserver = nil
    }
}
