//
//  FileVideoReference.swift
//  ASMR Walk Mac Importer
//

import AVFoundation
import Foundation
import UniformTypeIdentifiers

struct FileVideoReference: Equatable, Sendable {
    static let supportedContentTypes: [UTType] = [.mpeg4Movie, .quickTimeMovie]

    let displayName: String
    let bookmarkIdentifier: String
    let creationDate: Date?
    let duration: TimeInterval?

    static func load(from url: URL) async throws -> Self {
        do {
            guard let contentType = try url.resourceValues(forKeys: [.contentTypeKey]).contentType,
                  supportedContentTypes.contains(where: { contentType.conforms(to: $0) }) else {
                throw FileVideoError.unsupportedFormat
            }
        } catch let error as FileVideoError {
            throw error
        } catch {
            throw FileVideoError.inaccessible
        }

        guard url.startAccessingSecurityScopedResource() else {
            throw FileVideoError.accessDenied
        }
        defer { url.stopAccessingSecurityScopedResource() }

        let asset = AVURLAsset(url: url)
        let isPlayable: Bool
        do {
            isPlayable = try await asset.load(.isPlayable)
        } catch {
            throw FileVideoError.unreadable
        }
        guard isPlayable else {
            throw FileVideoError.unreadable
        }

        let duration = try? await asset.load(.duration).seconds
        let creationDate = try? await asset.load(.creationDate)?.load(.dateValue)
        let bookmark: Data
        do {
            bookmark = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: [.contentTypeKey],
                relativeTo: nil
            )
        } catch {
            throw FileVideoError.bookmarkCreationFailed
        }

        let reference = Self(
            displayName: url.lastPathComponent,
            bookmarkIdentifier: "security-scoped-bookmark:" + bookmark.base64EncodedString(),
            creationDate: creationDate,
            duration: duration?.isFinite == true ? duration : nil
        )
        _ = try reference.resolveURL()
        return reference
    }

    func resolveURL() throws -> URL {
        let prefix = "security-scoped-bookmark:"
        guard bookmarkIdentifier.hasPrefix(prefix),
              let data = Data(base64Encoded: String(bookmarkIdentifier.dropFirst(prefix.count))) else {
            throw FileVideoError.invalidBookmark
        }

        var isStale = false
        let url: URL
        do {
            url = try URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope, .withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
        } catch {
            throw FileVideoError.inaccessible
        }
        guard isStale == false else {
            throw FileVideoError.staleBookmark
        }
        return url
    }

    func packageReference(relativeTo routePreview: RoutePreview?) -> ASMRRoutePackage.VideoReference {
        ASMRRoutePackage.VideoReference(
            kind: .localVideo,
            displayName: displayName,
            sourceIdentifier: bookmarkIdentifier,
            startsAt: creationDate,
            offsetSeconds: offsetSeconds(relativeTo: routePreview),
            isEmbedded: false
        )
    }

    func offsetText(relativeTo routePreview: RoutePreview?) -> String? {
        guard let offset = offsetSeconds(relativeTo: routePreview) else { return nil }
        return Duration.seconds(offset).formatted(.time(pattern: .minuteSecond(padMinuteToLength: 2)))
    }

    var durationText: String? {
        guard let duration, duration.isFinite, duration >= 0 else { return nil }
        return Duration.seconds(duration).formatted(.time(pattern: .hourMinuteSecond(padHourToLength: 1)))
    }

    private func offsetSeconds(relativeTo routePreview: RoutePreview?) -> TimeInterval? {
        guard let routePreview, let creationDate else { return nil }
        return creationDate.timeIntervalSince(routePreview.routeStartedAt)
    }

    enum FileVideoError: LocalizedError, Equatable {
        case unsupportedFormat
        case accessDenied
        case unreadable
        case inaccessible
        case bookmarkCreationFailed
        case invalidBookmark
        case staleBookmark

        var errorDescription: String? {
            switch self {
            case .unsupportedFormat:
                "Choose a readable MP4 or MOV video file."
            case .accessDenied:
                "The selected video file could not be accessed."
            case .unreadable:
                "The selected video file could not be read as a playable movie."
            case .inaccessible:
                "The selected video file is missing or inaccessible. Choose it again to restore access."
            case .bookmarkCreationFailed:
                "ASMR Walk could not save durable access to the selected video. Choose a different file or location."
            case .invalidBookmark:
                "The saved video reference is invalid. Choose the video file again."
            case .staleBookmark:
                "The selected video moved or its saved access expired. Choose the video file again."
            }
        }
    }
}

protocol FileVideoReferenceLoading: Sendable {
    func load(from url: URL) async throws -> FileVideoReference
}

struct FileVideoReferenceLoader: FileVideoReferenceLoading {
    func load(from url: URL) async throws -> FileVideoReference {
        try await FileVideoReference.load(from: url)
    }
}
