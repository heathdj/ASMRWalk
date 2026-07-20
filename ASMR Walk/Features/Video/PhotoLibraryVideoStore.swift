//
//  PhotoLibraryVideoStore.swift
//  ASMR Walk
//

import AVFoundation
import Foundation
import Photos

enum PhotoLibraryVideoStore {
    static let saveAccessExplanation = "ASMR Walk saves a copy of this video walk to Photos when you choose Save Video to Photos."
    static let legacyReadAccessExplanation = "ASMR Walk reads older Photos-backed video walks so you can replay them with your route."

    enum StoreError: LocalizedError {
        case missingAddUsageDescription
        case missingReadUsageDescription
        case accessDenied
        case creationFailed
        case assetNotFound
        case playerItemUnavailable

        var errorDescription: String? {
            switch self {
            case .missingAddUsageDescription:
                "Photo Library add permission is not configured."
            case .missingReadUsageDescription:
                "Photo Library read permission is not configured."
            case .accessDenied:
                "Photo Library access was not available. The video walk was kept in the app instead."
            case .creationFailed:
                "The video could not be saved to Photos."
            case .assetNotFound:
                "The saved video could not be found in Photos."
            case .playerItemUnavailable:
                "The saved video could not be prepared for playback."
            }
        }
    }

    static func authorizationStatus(for accessLevel: PHAccessLevel) -> PHAuthorizationStatus {
        PHPhotoLibrary.authorizationStatus(for: accessLevel)
    }

    static func saveVideoToPhotoLibrary(from fileURL: URL) async throws -> String {
        try requireInfoPlistValue(for: "NSPhotoLibraryAddUsageDescription", error: StoreError.missingAddUsageDescription)
        guard await requestAccess(for: .addOnly) else {
            throw StoreError.accessDenied
        }

        var localIdentifier: String?
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: fileURL)
            localIdentifier = request?.placeholderForCreatedAsset?.localIdentifier
        }

        guard let localIdentifier else {
            throw StoreError.creationFailed
        }

        return localIdentifier
    }

    static func playerItem(for assetIdentifier: String) async throws -> AVPlayerItem {
        try requireInfoPlistValue(for: "NSPhotoLibraryUsageDescription", error: StoreError.missingReadUsageDescription)
        guard await requestAccess(for: .readWrite) else {
            throw StoreError.accessDenied
        }

        let result = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)
        guard let asset = result.firstObject, asset.mediaType == .video else {
            throw StoreError.assetNotFound
        }

        let options = PHVideoRequestOptions()
        options.deliveryMode = .automatic
        options.isNetworkAccessAllowed = true

        return try await withCheckedThrowingContinuation { continuation in
            PHImageManager.default().requestPlayerItem(forVideo: asset, options: options) { playerItem, info in
                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: error)
                    return
                }

                if (info?[PHImageCancelledKey] as? Bool) == true {
                    continuation.resume(throwing: CancellationError())
                    return
                }

                guard let playerItem else {
                    continuation.resume(throwing: StoreError.playerItemUnavailable)
                    return
                }

                continuation.resume(returning: playerItem)
            }
        }
    }

    private static func requestAccess(for accessLevel: PHAccessLevel) async -> Bool {
        switch PHPhotoLibrary.authorizationStatus(for: accessLevel) {
        case .authorized, .limited:
            true
        case .notDetermined:
            switch await PHPhotoLibrary.requestAuthorization(for: accessLevel) {
            case .authorized, .limited:
                true
            default:
                false
            }
        case .denied, .restricted:
            false
        @unknown default:
            false
        }
    }

    private static func requireInfoPlistValue(for key: String, error: StoreError) throws {
        guard Bundle.main.object(forInfoDictionaryKey: key) != nil else {
            throw error
        }
    }
}
