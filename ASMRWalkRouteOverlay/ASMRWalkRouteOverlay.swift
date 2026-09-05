//
//  ASMRWalkRouteOverlay.swift
//  ASMRWalkRouteOverlay
//

import CoreMedia
import Foundation

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
            kFxPropertyKey_NeedsFullBuffer: false,
            kFxPropertyKey_PixelTransformSupport: kFxPixelTransform_Full,
            kFxPropertyKey_VariesWhenParamsAreStatic: false
        ] as NSDictionary
    }

    func addParameters() throws {
        // Issue #76 only proves host discovery and lifecycle. Route package parameter UI
        // and rendering are implemented by #77 after the target is visible in Motion/FCP.
    }

    func pluginState(
        _ pluginState: AutoreleasingUnsafeMutablePointer<NSData>?,
        at renderTime: CMTime,
        quality qualityLevel: FxQuality
    ) throws {
        let state = ASMRWalkRouteOverlayState(
            packagePath: "",
            renderTimeSeconds: renderTime.seconds,
            qualityLevel: UInt(qualityLevel)
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
        // Deliberately no-op for target bring-up. #77 replaces this with deterministic
        // transparent route drawing from the decoded .asmrroute package.
    }
}

private struct ASMRWalkRouteOverlayState: Codable {
    let packagePath: String
    let renderTimeSeconds: Double
    let qualityLevel: UInt
}
