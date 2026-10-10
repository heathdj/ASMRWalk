//
//  ASMRWalkRouteOverlay.swift
//  ASMRWalkRouteOverlay
//

import CoreMedia
import CoreVideo
import Foundation
import IOSurface

@objc(ASMRWalkRouteOverlayPlugin)
final class ASMRWalkRouteOverlayPlugin: NSObject, FxTileableEffect {
    private weak var apiManager: PROAPIAccessing?

    required init?(apiManager: any PROAPIAccessing) {
        self.apiManager = apiManager
        super.init()
    }

    func properties(_ properties: AutoreleasingUnsafeMutablePointer<NSDictionary>?) throws {
        properties?.pointee = [
            kFxPropertyKey_ChangesOutputSize: false,
            kFxPropertyKey_MayRemapTime: false,
            kFxPropertyKey_NeedsFullBuffer: true,
            kFxPropertyKey_PixelTransformSupport: kFxPixelTransform_Full,
            kFxPropertyKey_VariesWhenParamsAreStatic: false
        ] as NSDictionary
    }

    func addParameters() throws {
        guard let parameterAPI = apiManager?.api(for: FxParameterCreationAPI_v5.self)
            as? FxParameterCreationAPI_v5 else {
            return
        }

        parameterAPI.addStringParameter(
            withName: "ASMR Route Package Path",
            parameterID: ASMRWalkRouteOverlayParameterID.packagePath,
            defaultValue: "",
            parameterFlags: FxParameterFlags(kFxParameterFlag_NOT_ANIMATABLE)
        )

        parameterAPI.addPopupMenu(
            withName: "Route Timing",
            parameterID: ASMRWalkRouteOverlayParameterID.timingMode,
            defaultValue: UInt32(ASMRRouteOverlayTimingMode.clipDuration.rawValue),
            menuEntries: ["Clip Duration", "GPX Timestamps"],
            parameterFlags: FxParameterFlags(kFxParameterFlag_NOT_ANIMATABLE)
        )

        parameterAPI.addToggleButton(
            withName: "Show Current Position",
            parameterID: ASMRWalkRouteOverlayParameterID.showCurrentPosition,
            defaultValue: true,
            parameterFlags: FxParameterFlags(kFxParameterFlag_DEFAULT)
        )

        parameterAPI.addToggleButton(
            withName: "Show Start and End Markers",
            parameterID: ASMRWalkRouteOverlayParameterID.showStartEndMarkers,
            defaultValue: true,
            parameterFlags: FxParameterFlags(kFxParameterFlag_DEFAULT)
        )
    }

    func pluginState(
        _ pluginState: AutoreleasingUnsafeMutablePointer<NSData>?,
        at renderTime: CMTime,
        quality qualityLevel: FxQuality
    ) throws {
        let packagePath = packagePath()
        let showCurrentPosition = boolParameter(
            ASMRWalkRouteOverlayParameterID.showCurrentPosition,
            defaultValue: true,
            at: renderTime
        )
        let showStartEndMarkers = boolParameter(
            ASMRWalkRouteOverlayParameterID.showStartEndMarkers,
            defaultValue: true,
            at: renderTime
        )
        let timingMode = timingMode(at: renderTime)
        let effectTiming = effectTiming()
        let renderPlan = Self.renderPlan(
            packagePath: packagePath,
            renderTimeSeconds: renderTime.seconds,
            effectStartSeconds: effectTiming.startSeconds,
            effectDurationSeconds: effectTiming.durationSeconds,
            timingMode: timingMode,
            showCurrentPosition: showCurrentPosition,
            showStartEndMarkers: showStartEndMarkers
        )

        let state = ASMRWalkRouteOverlayState(
            packagePath: packagePath,
            renderTimeSeconds: renderTime.seconds,
            qualityLevel: UInt(qualityLevel),
            renderPlan: renderPlan
        )
        pluginState?.pointee = try JSONEncoder().encode(state) as NSData
    }

    func destinationImageRect(
        _ destinationImageRect: UnsafeMutablePointer<FxRect>,
        sourceImages: [FxImageTile],
        destinationImage: FxImageTile,
        pluginState: Data?,
        at renderTime: CMTime
    ) throws {
        destinationImageRect.pointee = destinationImage.imagePixelBounds
    }

    func sourceTileRect(
        _ sourceTileRect: UnsafeMutablePointer<FxRect>,
        sourceImageIndex: UInt,
        sourceImages: [FxImageTile],
        destinationTileRect: FxRect,
        destinationImage: FxImageTile,
        pluginState: Data?,
        at renderTime: CMTime
    ) throws {
        sourceTileRect.pointee = kFxRect_Empty
    }

    func renderDestinationImage(
        _ destinationImage: FxImageTile,
        sourceImages: [FxImageTile],
        pluginState: Data?,
        at renderTime: CMTime
    ) throws {
        guard
            let surface = destinationImage.ioSurface
        else {
            return
        }

        let state = try pluginState.flatMap {
            try JSONDecoder().decode(ASMRWalkRouteOverlayState.self, from: $0)
        }
        let width = IOSurfaceGetWidth(surface)
        let height = IOSurfaceGetHeight(surface)
        let bytesPerRow = IOSurfaceGetBytesPerRow(surface)
        let pixelFormat = Self.pixelFormat(for: IOSurfaceGetPixelFormat(surface))

        IOSurfaceLock(surface, [], nil)
        defer { IOSurfaceUnlock(surface, [], nil) }
        let baseAddress = IOSurfaceGetBaseAddress(surface)

        ASMRRouteOverlayRenderer.render(
            state?.renderPlan ?? .empty,
            into: baseAddress,
            width: width,
            height: height,
            bytesPerRow: bytesPerRow,
            pixelFormat: pixelFormat
        )
    }

    private func packagePath() -> String {
        guard let retrievalAPI = apiManager?.api(for: FxParameterRetrievalAPI_v6.self)
            as? FxParameterRetrievalAPI_v6 else {
            return ""
        }

        var value = "" as NSString
        guard retrievalAPI.getStringParameterValue(&value, fromParameter: ASMRWalkRouteOverlayParameterID.packagePath) else {
            return ""
        }

        return (value as String).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func boolParameter(_ parameterID: UInt32, defaultValue: Bool, at time: CMTime) -> Bool {
        guard let retrievalAPI = apiManager?.api(for: FxParameterRetrievalAPI_v6.self)
            as? FxParameterRetrievalAPI_v6 else {
            return defaultValue
        }

        var value = ObjCBool(defaultValue)
        guard retrievalAPI.getBoolValue(&value, fromParameter: parameterID, at: time) else {
            return defaultValue
        }

        return value.boolValue
    }

    private func timingMode(at time: CMTime) -> ASMRRouteOverlayTimingMode {
        guard let retrievalAPI = apiManager?.api(for: FxParameterRetrievalAPI_v6.self)
            as? FxParameterRetrievalAPI_v6 else {
            return .clipDuration
        }

        var value = Int32(ASMRRouteOverlayTimingMode.clipDuration.rawValue)
        guard retrievalAPI.getIntValue(
            &value,
            fromParameter: ASMRWalkRouteOverlayParameterID.timingMode,
            at: time
        ) else {
            return .clipDuration
        }

        return ASMRRouteOverlayTimingMode(rawValue: Int(value)) ?? .clipDuration
    }

    private func effectTiming() -> (startSeconds: TimeInterval, durationSeconds: TimeInterval?) {
        guard let timingAPI = apiManager?.api(for: FxTimingAPI_v5.self) as? FxTimingAPI_v5 else {
            return (0, nil)
        }

        var startTime = CMTime.zero
        var duration = CMTime.invalid
        timingAPI.startTime(forEffect: &startTime)
        timingAPI.durationTime(forEffect: &duration)

        return (
            startTime.seconds.isFinite ? startTime.seconds : 0,
            duration.seconds.isFinite && duration.seconds > 0 ? duration.seconds : nil
        )
    }

    private static func renderPlan(
        packagePath: String,
        renderTimeSeconds: TimeInterval,
        effectStartSeconds: TimeInterval,
        effectDurationSeconds: TimeInterval?,
        timingMode: ASMRRouteOverlayTimingMode,
        showCurrentPosition: Bool,
        showStartEndMarkers: Bool
    ) -> ASMRRouteOverlayRenderPlan {
        guard !packagePath.isEmpty else { return .empty }

        do {
            let routePackage = try ASMRRoutePackageInput.load(from: URL(fileURLWithPath: packagePath))
            return ASMRRouteOverlayRenderPlan.make(
                from: routePackage,
                renderTimeSeconds: renderTimeSeconds,
                effectStartSeconds: effectStartSeconds,
                effectDurationSeconds: effectDurationSeconds,
                timingMode: timingMode,
                showCurrentPosition: showCurrentPosition,
                showStartEndMarkers: showStartEndMarkers
            )
        } catch {
            return .empty
        }
    }

    private static func pixelFormat(for surfacePixelFormat: UInt32) -> ASMRRouteOverlayPixelFormat {
        switch surfacePixelFormat {
        case kCVPixelFormatType_32BGRA:
            .bgra
        case kCVPixelFormatType_32RGBA:
            .rgba
        default:
            .bgra
        }
    }
}

private struct ASMRWalkRouteOverlayState: Codable {
    let packagePath: String
    let renderTimeSeconds: Double
    let qualityLevel: UInt
    let renderPlan: ASMRRouteOverlayRenderPlan
}

private enum ASMRWalkRouteOverlayParameterID {
    static let packagePath: UInt32 = 1
    static let showCurrentPosition: UInt32 = 2
    static let showStartEndMarkers: UInt32 = 3
    static let timingMode: UInt32 = 4
}
