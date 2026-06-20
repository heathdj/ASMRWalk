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
    @State private var loadErrorMessage: String?

    var body: some View {
        Group {
            if recording.hasVideo {
                ZStack(alignment: .topTrailing) {
                    if let player {
                        VideoPlayer(player: player)
                            .background(.black)
                    } else if let loadErrorMessage {
                        ContentUnavailableView(
                            "Video Unavailable",
                            systemImage: "video.slash",
                            description: Text(loadErrorMessage)
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.black)
                        .foregroundStyle(.white)
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
                .task(id: playbackIdentifier) {
                    await configurePlayer()
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

    private var playbackIdentifier: String {
        recording.videoAssetIdentifier ?? recording.videoURL?.absoluteString ?? "missing-video"
    }

    private func configurePlayer() async {
        removeTimeObserver()
        loadErrorMessage = nil
        currentTime = 0

        do {
            let player: AVPlayer
            if let assetIdentifier = recording.videoAssetIdentifier {
                let playerItem = try await PhotoLibraryVideoStore.playerItem(for: assetIdentifier)
                player = AVPlayer(playerItem: playerItem)
            } else if let videoURL = recording.videoURL,
                      FileManager.default.fileExists(atPath: videoURL.path) {
                player = AVPlayer(url: videoURL)
            } else {
                throw CocoaError(.fileNoSuchFile)
            }

            self.player = player

            let interval = CMTime(value: 1, timescale: 2)
            timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
                currentTime = time.seconds.isFinite ? time.seconds : 0
            }
        } catch {
            player = nil
            loadErrorMessage = error.localizedDescription
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
