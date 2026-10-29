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
    private static let packageCache = ASMRRouteOverlayPackageCache()

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

        parameterAPI.addToggleButton(
            withName: "Map Background",
            parameterID: ASMRWalkRouteOverlayParameterID.showMapBackground,
            defaultValue: true,
            parameterFlags: FxParameterFlags(kFxParameterFlag_NOT_ANIMATABLE)
        )

        parameterAPI.addPopupMenu(
            withName: "Map Position",
            parameterID: ASMRWalkRouteOverlayParameterID.mapPosition,
            defaultValue: 1,
            menuEntries: ["Top Left", "Top Right", "Bottom Left", "Bottom Right", "Center"],
            parameterFlags: FxParameterFlags(kFxParameterFlag_DEFAULT)
        )
        parameterAPI.addPopupMenu(
            withName: "Map Size",
            parameterID: ASMRWalkRouteOverlayParameterID.mapSize,
            defaultValue: 1,
            menuEntries: ["Small", "Medium", "Large"],
            parameterFlags: FxParameterFlags(kFxParameterFlag_DEFAULT)
        )
        parameterAPI.addPopupMenu(
            withName: "Map Corners",
            parameterID: ASMRWalkRouteOverlayParameterID.mapCorners,
            defaultValue: 1,
            menuEntries: ["Square", "Rounded", "Very Rounded"],
            parameterFlags: FxParameterFlags(kFxParameterFlag_DEFAULT)
        )
        parameterAPI.addPopupMenu(
            withName: "Map Opacity",
            parameterID: ASMRWalkRouteOverlayParameterID.mapOpacity,
            defaultValue: 2,
            menuEntries: ["50%", "75%", "90%", "100%"],
            parameterFlags: FxParameterFlags(kFxParameterFlag_DEFAULT)
        )

        parameterAPI.addStringParameter(
            withName: "Map Status",
            parameterID: ASMRWalkRouteOverlayParameterID.mapStatus,
            defaultValue: "Select an ASMR route package",
            parameterFlags: FxParameterFlags(kFxParameterFlag_NOT_ANIMATABLE | kFxParameterFlag_DISABLED)
        )
    }

    func pluginInstanceAddedToDocument() {
        updateMapControls(at: .zero)
    }

    func parameterChanged(_ parameterID: UInt32, at time: CMTime) throws {
        guard parameterID == ASMRWalkRouteOverlayParameterID.packagePath else { return }
        updateMapControls(at: time)
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
        let showMapBackground = boolParameter(
            ASMRWalkRouteOverlayParameterID.showMapBackground,
            defaultValue: true,
            at: renderTime
        )
        let mapStyle = mapStyle(at: renderTime)
        let effectTiming = effectTiming()
        let renderPlan = Self.renderPlan(
            packagePath: packagePath,
            renderTimeSeconds: renderTime.seconds,
            effectStartSeconds: effectTiming.startSeconds,
            effectDurationSeconds: effectTiming.durationSeconds,
            timingMode: timingMode,
            showCurrentPosition: showCurrentPosition,
            showStartEndMarkers: showStartEndMarkers,
            showMapBackground: showMapBackground,
            mapStyle: mapStyle
        )

        let state = ASMRWalkRouteOverlayState(
            packagePath: packagePath,
            renderTimeSeconds: renderTime.seconds,
            qualityLevel: UInt(qualityLevel),
            renderPlan: renderPlan.removingMapBackgroundBitmap(),
            showsMapBackground: showMapBackground && renderPlan.mapBackground != nil
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
        let mapBackground: ASMRRouteOverlayBitmap? = state.flatMap { state in
            guard state.showsMapBackground else { return nil }
            return try? Self.packageCache.preparedPackage(
                at: URL(fileURLWithPath: state.packagePath)
            ).mapBackground
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
            pixelFormat: pixelFormat,
            mapBackgroundOverride: mapBackground
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

    private func updateMapControls(at time: CMTime) {
        guard let settingAPI = apiManager?.api(for: FxParameterSettingAPI_v5.self)
            as? FxParameterSettingAPI_v5 else { return }

        let path = packagePath()
        let availability: ASMRRouteMapAvailability
        if path.isEmpty {
            availability = .routeOnly
        } else if let preparedPackage = try? Self.packageCache.preparedPackage(at: URL(fileURLWithPath: path)) {
            availability = preparedPackage.mapAvailability
        } else {
            availability = .unusable
        }

        let mapAvailable = availability.isAvailable
        settingAPI.setStringParameterValue(
            availability.statusMessage,
            toParameter: ASMRWalkRouteOverlayParameterID.mapStatus
        )
        settingAPI.setBoolValue(
            mapAvailable,
            toParameter: ASMRWalkRouteOverlayParameterID.showMapBackground,
            at: time
        )

        let toggleFlags = mapAvailable
            ? kFxParameterFlag_NOT_ANIMATABLE
            : kFxParameterFlag_NOT_ANIMATABLE | kFxParameterFlag_DISABLED
        settingAPI.setParameterFlags(
            FxParameterFlags(toggleFlags),
            toParameter: ASMRWalkRouteOverlayParameterID.showMapBackground
        )

        let controlFlags = FxParameterFlags(mapAvailable ? kFxParameterFlag_DEFAULT : kFxParameterFlag_DISABLED)
        for parameterID in [
            ASMRWalkRouteOverlayParameterID.mapPosition,
            ASMRWalkRouteOverlayParameterID.mapSize,
            ASMRWalkRouteOverlayParameterID.mapCorners,
            ASMRWalkRouteOverlayParameterID.mapOpacity
        ] {
            settingAPI.setParameterFlags(controlFlags, toParameter: parameterID)
        }
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

    private func intParameter(_ parameterID: UInt32, defaultValue: Int, at time: CMTime) -> Int {
        guard let retrievalAPI = apiManager?.api(for: FxParameterRetrievalAPI_v6.self)
            as? FxParameterRetrievalAPI_v6 else { return defaultValue }
        var value = Int32(defaultValue)
        return retrievalAPI.getIntValue(&value, fromParameter: parameterID, at: time)
            ? Int(value)
            : defaultValue
    }

    private func mapStyle(at time: CMTime) -> ASMRRouteOverlayMapStyle {
        let position = intParameter(ASMRWalkRouteOverlayParameterID.mapPosition, defaultValue: 1, at: time)
        let size = intParameter(ASMRWalkRouteOverlayParameterID.mapSize, defaultValue: 1, at: time)
        let corners = intParameter(ASMRWalkRouteOverlayParameterID.mapCorners, defaultValue: 1, at: time)
        let opacity = intParameter(ASMRWalkRouteOverlayParameterID.mapOpacity, defaultValue: 2, at: time)
        let centers = [(0.25, 0.25), (0.75, 0.25), (0.25, 0.75), (0.75, 0.75), (0.5, 0.5)]
        let dimensions = [(0.28, 0.28), (0.42, 0.42), (0.62, 0.62)]
        let resolvedCenter = centers.indices.contains(position) ? centers[position] : centers[1]
        let resolvedSize = dimensions.indices.contains(size) ? dimensions[size] : dimensions[1]
        let cornerValues = [0.0, 0.06, 0.16]
        let opacityValues = [0.5, 0.75, 0.9, 1.0]
        return ASMRRouteOverlayMapStyle(
            centerX: resolvedCenter.0,
            centerY: resolvedCenter.1,
            widthFraction: resolvedSize.0,
            heightFraction: resolvedSize.1,
            cornerRadiusFraction: cornerValues.indices.contains(corners) ? cornerValues[corners] : cornerValues[1],
            opacity: opacityValues.indices.contains(opacity) ? opacityValues[opacity] : opacityValues[2]
        )
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
        showStartEndMarkers: Bool,
        showMapBackground: Bool,
        mapStyle: ASMRRouteOverlayMapStyle
    ) -> ASMRRouteOverlayRenderPlan {
        guard !packagePath.isEmpty else { return .empty }

        do {
            let preparedPackage = try packageCache.preparedPackage(at: URL(fileURLWithPath: packagePath))
            return ASMRRouteOverlayRenderPlan.make(
                from: preparedPackage.routePackage,
                renderTimeSeconds: renderTimeSeconds,
                effectStartSeconds: effectStartSeconds,
                effectDurationSeconds: effectDurationSeconds,
                timingMode: timingMode,
                showCurrentPosition: showCurrentPosition,
                showStartEndMarkers: showStartEndMarkers,
                showMapBackground: showMapBackground,
                mapStyle: mapStyle,
                preparedMapBackground: preparedPackage.mapBackground,
                preparedMapBackgrounds: preparedPackage.mapBackgrounds,
                usesPreparedMapBackground: true
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
    let showsMapBackground: Bool
}

private enum ASMRWalkRouteOverlayParameterID {
    static let packagePath: UInt32 = 1
    static let showCurrentPosition: UInt32 = 2
    static let showStartEndMarkers: UInt32 = 3
    static let timingMode: UInt32 = 4
    static let showMapBackground: UInt32 = 5
    static let mapPosition: UInt32 = 6
    static let mapSize: UInt32 = 7
    static let mapCorners: UInt32 = 8
    static let mapOpacity: UInt32 = 9
    static let mapStatus: UInt32 = 10
}
