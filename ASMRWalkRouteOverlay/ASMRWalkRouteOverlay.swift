//
//  ASMRWalkRouteOverlay.swift
//  ASMRWalkRouteOverlay
//

import AppKit
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
            withName: "Saved Route Package Selection",
            parameterID: ASMRWalkRouteOverlayParameterID.packageSelection,
            defaultValue: "",
            parameterFlags: FxParameterFlags(kFxParameterFlag_NOT_ANIMATABLE | kFxParameterFlag_HIDDEN)
        )
        parameterAPI.addPushButton(
            withName: "Choose or Replace Route Package…",
            parameterID: ASMRWalkRouteOverlayParameterID.choosePackage,
            selector: #selector(chooseRoutePackage),
            parameterFlags: FxParameterFlags(kFxParameterFlag_NOT_ANIMATABLE)
        )
        parameterAPI.addPushButton(
            withName: "Clear Route Package",
            parameterID: ASMRWalkRouteOverlayParameterID.clearPackage,
            selector: #selector(clearRoutePackage),
            parameterFlags: FxParameterFlags(kFxParameterFlag_NOT_ANIMATABLE)
        )
        parameterAPI.addStringParameter(
            withName: "Route Package",
            parameterID: ASMRWalkRouteOverlayParameterID.packageStatus,
            defaultValue: "No route package selected",
            parameterFlags: FxParameterFlags(kFxParameterFlag_NOT_ANIMATABLE | kFxParameterFlag_DISABLED)
        )

        parameterAPI.addPopupMenu(
            withName: "Route Timing",
            parameterID: ASMRWalkRouteOverlayParameterID.timingMode,
            defaultValue: UInt32(ASMRRouteOverlayTimingMode.clipDuration.rawValue),
            menuEntries: ["Clip Duration", "GPX Timestamps"],
            parameterFlags: FxParameterFlags(kFxParameterFlag_NOT_ANIMATABLE)
        )
        parameterAPI.addFloatSlider(
            withName: "Timing Offset (seconds)",
            parameterID: ASMRWalkRouteOverlayParameterID.timingOffset,
            defaultValue: 0,
            parameterMin: -86_400,
            parameterMax: 86_400,
            sliderMin: -30,
            sliderMax: 30,
            delta: 0.1,
            parameterFlags: FxParameterFlags(kFxParameterFlag_DEFAULT)
        )
        parameterAPI.addStringParameter(
            withName: "Timing Status",
            parameterID: ASMRWalkRouteOverlayParameterID.timingStatus,
            defaultValue: "No package video timing",
            parameterFlags: FxParameterFlags(kFxParameterFlag_NOT_ANIMATABLE | kFxParameterFlag_DISABLED)
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
        updatePackageControls(at: .zero)
    }

    func parameterChanged(_ parameterID: UInt32, at time: CMTime) throws {
        if parameterID == ASMRWalkRouteOverlayParameterID.packageSelection
            || parameterID == ASMRWalkRouteOverlayParameterID.timingOffset {
            updatePackageControls(at: time)
        }
    }

    func pluginState(
        _ pluginState: AutoreleasingUnsafeMutablePointer<NSData>?,
        at renderTime: CMTime,
        quality qualityLevel: FxQuality
    ) throws {
        let selectionData = packageSelectionData()
        let packageURL = resolvedPackageURL(from: selectionData)
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
        let explicitTimingOffset = floatParameter(
            ASMRWalkRouteOverlayParameterID.timingOffset,
            defaultValue: 0,
            at: renderTime
        )
        let showMapBackground = boolParameter(
            ASMRWalkRouteOverlayParameterID.showMapBackground,
            defaultValue: true,
            at: renderTime
        )
        let mapStyle = mapStyle(at: renderTime)
        let effectTiming = effectTiming()
        let renderPlan = Self.renderPlan(
            packageURL: packageURL,
            renderTimeSeconds: renderTime.seconds,
            effectStartSeconds: effectTiming.startSeconds,
            effectDurationSeconds: effectTiming.durationSeconds,
            timingMode: timingMode,
            explicitTimingOffsetSeconds: explicitTimingOffset,
            showCurrentPosition: showCurrentPosition,
            showStartEndMarkers: showStartEndMarkers,
            showMapBackground: showMapBackground,
            mapStyle: mapStyle
        )

        let state = ASMRWalkRouteOverlayState(
            packageSelectionData: selectionData,
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
            guard let url = Self.resolvedPackageURL(from: state.packageSelectionData) else { return nil }
            guard let package = Self.packageCache.cachedPreparedPackage(at: url) else { return nil }
            if let filename = state.renderPlan.mapBackgroundFilename {
                return package.mapBackgrounds.first { $0.metadata.filename == filename }?.bitmap
                    ?? package.mapBackground
            }
            return package.mapBackground
        }
        let width = IOSurfaceGetWidth(surface)
        let height = IOSurfaceGetHeight(surface)
        let bytesPerRow = IOSurfaceGetBytesPerRow(surface)
        guard let pixelFormat = Self.pixelFormat(for: IOSurfaceGetPixelFormat(surface)) else {
            throw NSError(domain: "ASMRWalkRouteOverlay", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Unsupported host pixel format: \(IOSurfaceGetPixelFormat(surface))"
            ])
        }

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
            mapBackgroundOverride: mapBackground,
            flipVertically: destinationImage.imageOrigin == kFxImageOrigin_BOTTOM_LEFT,
            premultiplyAlpha: true
        )
    }

    private func packageSelectionData() -> String {
        guard let retrievalAPI = apiManager?.api(for: FxParameterRetrievalAPI_v6.self)
            as? FxParameterRetrievalAPI_v6 else {
            return ""
        }

        var value = "" as NSString
        guard retrievalAPI.getStringParameterValue(&value, fromParameter: ASMRWalkRouteOverlayParameterID.packageSelection) else {
            return ""
        }

        return (value as String).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @objc private func chooseRoutePackage() {
        guard let remoteWindowAPI = apiManager?.api(for: FxRemoteWindowAPI_v2.self)
            as? FxRemoteWindowAPI_v2 else {
            return
        }

        remoteWindowAPI.remoteWindow(
            withMinimumSize: CGSize(width: 460, height: 220),
            maximumSize: CGSize(width: 460, height: 220)
        ) { [weak self] parentView, _ in
            guard let parentView else { return }
            DispatchQueue.main.async { [weak self] in
                guard self != nil else { return }
                // FxServiceView.nib starts at 222x158 with flexible margins (mask 45).
                // Without resizing this parent, the 460x220 host centers that small
                // view at (119, 31), and our full-size child spills out to the right.
                parentView.autoresizingMask = [.width, .height]
                parentView.frame = NSRect(x: 0, y: 0, width: 460, height: 220)
                // The host may return the same remote view when the chooser is reopened.
                parentView.subviews.compactMap { $0 as? ASMRRoutePackageDropView }.forEach { $0.removeFromSuperview() }
                let chooserView = ASMRRoutePackageDropView(frame: NSRect(x: 0, y: 0, width: 460, height: 220)) { [weak self] url in
                    guard let self else { return }
                    try self.selectRoutePackage(at: url)
                } dismiss: { [weak self] in
                    // This NSView belongs to a remote view service, not the host's NSWindow.
                    (self?.apiManager?.api(for: FxRemoteWindowAPI_v3.self) as? FxRemoteWindowAPI_v3)?
                        .closeRemoteWindow()
                }
                chooserView.autoresizingMask = [.width, .height]
                parentView.addSubview(chooserView)
            }
        }
    }

    private func selectRoutePackage(at url: URL) throws {
        _ = try Self.withSecurityScopedAccess(to: url) {
            try Self.packageCache.preparedPackage(at: url)
        }
        let bookmark = try url.bookmarkData(
            options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
            includingResourceValuesForKeys: [.nameKey],
            relativeTo: nil
        )
        let selection = ASMRRoutePackageSelection(
            bookmarkData: bookmark,
            displayName: url.deletingPathExtension().lastPathComponent,
            lastKnownPath: url.path
        )
        let encodedSelection = try selection.encoded()
        performCustomParameterAction {
            setPackageSelectionData(encodedSelection)
            updatePackageControls(at: .zero)
        }
    }

    @objc private func clearRoutePackage() {
        // Avoid unnecessary host parameter writes. In particular, Final Cut Pro
        // may invoke this published button before the hidden selection parameter
        // has ever been initialized for the generator instance.
        guard packageSelectionData().isEmpty == false else { return }
        setPackageSelectionData("")
        updatePackageControls(at: .zero)
    }

    private func performCustomParameterAction(_ action: () -> Void) {
        guard let actionAPI = apiManager?.api(for: FxCustomParameterActionAPI_v4.self)
            as? FxCustomParameterActionAPI_v4 else { return }

        actionAPI.startAction(self)
        defer { actionAPI.endAction(self) }
        action()
    }

    private func setPackageSelectionData(_ value: String) {
        guard let settingAPI = apiManager?.api(for: FxParameterSettingAPI_v5.self)
            as? FxParameterSettingAPI_v5 else { return }
        settingAPI.setStringParameterValue(value, toParameter: ASMRWalkRouteOverlayParameterID.packageSelection)
    }

    private func setStatus(_ value: String) {
        guard let settingAPI = apiManager?.api(for: FxParameterSettingAPI_v5.self)
            as? FxParameterSettingAPI_v5 else { return }
        settingAPI.setStringParameterValue(value, toParameter: ASMRWalkRouteOverlayParameterID.packageStatus)
    }

    private func updatePackageControls(at time: CMTime) {
        guard let settingAPI = apiManager?.api(for: FxParameterSettingAPI_v5.self)
            as? FxParameterSettingAPI_v5 else { return }

        let selectionData = packageSelectionData()
        let packageURL = resolvedPackageURL(from: selectionData)
        let availability: ASMRRouteMapAvailability
        let packageStatus: String
        let timingStatus: String
        if selectionData.isEmpty {
            availability = .routeOnly
            packageStatus = "No route package selected"
            timingStatus = "No package video timing"
        } else if let packageURL,
                  let preparedPackage = try? Self.withSecurityScopedAccess(to: packageURL, {
                      try Self.packageCache.preparedPackage(at: packageURL)
                  }) {
            availability = preparedPackage.mapAvailability
            packageStatus = "\(preparedPackage.routePackage.manifest.title) — Ready"
            let alignment = ASMRRouteTimingAlignment.resolve(
                manifest: preparedPackage.routePackage.manifest,
                explicitOffsetSeconds: floatParameter(
                    ASMRWalkRouteOverlayParameterID.timingOffset,
                    defaultValue: 0,
                    at: time
                )
            )
            timingStatus = alignment.statusMessage
        } else {
            availability = .unusable
            packageStatus = "Route package is unavailable — choose it again"
            timingStatus = "Package timing unavailable"
        }

        let mapAvailable = availability.isAvailable
        settingAPI.setStringParameterValue(
            availability.statusMessage,
            toParameter: ASMRWalkRouteOverlayParameterID.mapStatus
        )
        settingAPI.setStringParameterValue(packageStatus, toParameter: ASMRWalkRouteOverlayParameterID.packageStatus)
        settingAPI.setStringParameterValue(timingStatus, toParameter: ASMRWalkRouteOverlayParameterID.timingStatus)
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

    private func floatParameter(_ parameterID: UInt32, defaultValue: Double, at time: CMTime) -> Double {
        guard let retrievalAPI = apiManager?.api(for: FxParameterRetrievalAPI_v6.self)
            as? FxParameterRetrievalAPI_v6 else { return defaultValue }
        var value = defaultValue
        return retrievalAPI.getFloatValue(&value, fromParameter: parameterID, at: time) ? value : defaultValue
    }

    private func resolvedPackageURL(from selectionData: String) -> URL? {
        Self.resolvedPackageURL(from: selectionData)
    }

    private static func resolvedPackageURL(from selectionData: String) -> URL? {
        guard selectionData.isEmpty == false else { return nil }
        if selectionData.hasPrefix("/") {
            return URL(fileURLWithPath: selectionData)
        }
        guard let selection = try? ASMRRoutePackageSelection.decode(selectionData) else { return nil }
        var isStale = false
        return try? URL(
            resolvingBookmarkData: selection.bookmarkData,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
    }

    private static func withSecurityScopedAccess<T>(to url: URL, _ operation: () throws -> T) rethrows -> T {
        let didStartAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess { url.stopAccessingSecurityScopedResource() }
        }
        return try operation()
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
        packageURL: URL?,
        renderTimeSeconds: TimeInterval,
        effectStartSeconds: TimeInterval,
        effectDurationSeconds: TimeInterval?,
        timingMode: ASMRRouteOverlayTimingMode,
        explicitTimingOffsetSeconds: TimeInterval,
        showCurrentPosition: Bool,
        showStartEndMarkers: Bool,
        showMapBackground: Bool,
        mapStyle: ASMRRouteOverlayMapStyle
    ) -> ASMRRouteOverlayRenderPlan {
        guard let packageURL else { return .empty }

        do {
            let preparedPackage = if let cached = packageCache.cachedPreparedPackage(at: packageURL) {
                cached
            } else {
                try withSecurityScopedAccess(to: packageURL) {
                    try packageCache.preparedPackage(at: packageURL)
                }
            }
            let alignment = ASMRRouteTimingAlignment.resolve(
                manifest: preparedPackage.routePackage.manifest,
                explicitOffsetSeconds: explicitTimingOffsetSeconds
            )
            return ASMRRouteOverlayRenderPlan.make(
                from: preparedPackage.routePackage,
                renderTimeSeconds: renderTimeSeconds,
                effectStartSeconds: effectStartSeconds,
                effectDurationSeconds: effectDurationSeconds,
                routeTimingOffsetSeconds: alignment.totalOffsetSeconds,
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

    private static func pixelFormat(for surfacePixelFormat: UInt32) -> ASMRRouteOverlayPixelFormat? {
        switch surfacePixelFormat {
        case kCVPixelFormatType_32BGRA:
            .bgra
        case kCVPixelFormatType_32RGBA:
            .rgba
        case kCVPixelFormatType_64RGBAHalf:
            .rgbaHalf
        case kCVPixelFormatType_128RGBAFloat:
            .rgbaFloat
        default:
            nil
        }
    }
}

private final class ASMRRoutePackageDropView: NSView {
    private var borderColor = NSColor.separatorColor {
        didSet { needsDisplay = true }
    }
    private let selectPackage: (URL) throws -> Void
    private let dismiss: () -> Void
    private let instructionLabel = NSTextField(labelWithString: "Drop an .asmrroute package here")
    private let statusLabel = NSTextField(labelWithString: "Drag the package from Finder to choose or replace the route.")

    init(frame frameRect: NSRect, selectPackage: @escaping (URL) throws -> Void, dismiss: @escaping () -> Void) {
        self.dismiss = dismiss
        self.selectPackage = selectPackage
        super.init(frame: frameRect)

        // Keep the drop-target border inset within the local content area.
        registerForDraggedTypes([.fileURL])

        instructionLabel.alignment = .center
        instructionLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        instructionLabel.lineBreakMode = .byWordWrapping
        instructionLabel.maximumNumberOfLines = 2
        instructionLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.alignment = .center
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byWordWrapping
        statusLabel.maximumNumberOfLines = 2
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(instructionLabel)
        addSubview(statusLabel)
        NSLayoutConstraint.activate([
            instructionLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            instructionLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            instructionLabel.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -18),
            statusLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            statusLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            statusLabel.topAnchor.constraint(equalTo: instructionLabel.bottomAnchor, constant: 12)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        borderColor.setStroke()
        let border = NSBezierPath(roundedRect: bounds.insetBy(dx: 12, dy: 12), xRadius: 14, yRadius: 14)
        border.lineWidth = 2
        border.stroke()
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard droppedPackageURL(from: sender) != nil else {
            statusLabel.stringValue = "Drop one .asmrroute package."
            statusLabel.textColor = .systemRed
            return []
        }
        borderColor = .controlAccentColor
        statusLabel.stringValue = "Release to use this route package."
        statusLabel.textColor = .controlAccentColor
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        restorePrompt()
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let url = droppedPackageURL(from: sender) else { return false }
        do {
            try selectPackage(url)
            instructionLabel.stringValue = "Route package selected"
            statusLabel.stringValue = url.deletingPathExtension().lastPathComponent
            statusLabel.textColor = .systemGreen
            borderColor = .systemGreen
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                self?.dismiss()
            }
            return true
        } catch {
            instructionLabel.stringValue = "Could not use that package"
            statusLabel.stringValue = error.localizedDescription
            statusLabel.textColor = .systemRed
            borderColor = .systemRed
            return false
        }
    }

    private func droppedPackageURL(from draggingInfo: NSDraggingInfo) -> URL? {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        guard let urls = draggingInfo.draggingPasteboard.readObjects(
            forClasses: [NSURL.self],
            options: options
        ) as? [URL], urls.count == 1 else {
            return nil
        }
        let url = urls[0]
        return url.pathExtension.lowercased() == "asmrroute" ? url : nil
    }

    private func restorePrompt() {
        instructionLabel.stringValue = "Drop an .asmrroute package here"
        statusLabel.stringValue = "Drag the package from Finder to choose or replace the route."
        statusLabel.textColor = .secondaryLabelColor
        borderColor = .separatorColor
    }
}

private struct ASMRWalkRouteOverlayState: Codable {
    let packageSelectionData: String
    let renderTimeSeconds: Double
    let qualityLevel: UInt
    let renderPlan: ASMRRouteOverlayRenderPlan
    let showsMapBackground: Bool
}

private enum ASMRWalkRouteOverlayParameterID {
    static let packageSelection: UInt32 = 1
    static let showCurrentPosition: UInt32 = 2
    static let showStartEndMarkers: UInt32 = 3
    static let timingMode: UInt32 = 4
    static let showMapBackground: UInt32 = 5
    static let mapPosition: UInt32 = 6
    static let mapSize: UInt32 = 7
    static let mapCorners: UInt32 = 8
    static let mapOpacity: UInt32 = 9
    static let mapStatus: UInt32 = 10
    static let choosePackage: UInt32 = 11
    static let clearPackage: UInt32 = 12
    static let packageStatus: UInt32 = 13
    static let timingOffset: UInt32 = 14
    static let timingStatus: UInt32 = 15
}
