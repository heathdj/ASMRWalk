//
//  InterfaceOrientationController.swift
//  ASMR Walk
//

import UIKit

final class AppOrientationDelegate: NSObject, UIApplicationDelegate {
    static var supportedOrientations: UIInterfaceOrientationMask = .portrait

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        Self.supportedOrientations
    }
}

enum AppOrientationPolicy {
    static func orientationMask(for tab: AppTab) -> UIInterfaceOrientationMask {
        tab == .videoWalk ? .landscapeRight : .portrait
    }
}

@MainActor
enum InterfaceOrientationController {
    static let videoWalkOrientation: UIInterfaceOrientation = .landscapeRight

    static var currentInterfaceOrientation: UIInterfaceOrientation {
        activeScene?.effectiveGeometry.interfaceOrientation ?? .landscapeRight
    }

    static func videoRotationAngle(for orientation: UIInterfaceOrientation) -> CGFloat {
        switch orientation {
        case .landscapeLeft:
            180
        case .portrait:
            90
        case .portraitUpsideDown:
            270
        case .landscapeRight, .unknown:
            0
        @unknown default:
            0
        }
    }

    static func applyPolicy(for tab: AppTab) {
        let orientationMask = AppOrientationPolicy.orientationMask(for: tab)
        AppOrientationDelegate.supportedOrientations = orientationMask
        updateSupportedInterfaceOrientations()
        request(orientationMask)
    }

    static func request(_ orientations: UIInterfaceOrientationMask) {
        guard let scene = activeScene else {
            return
        }

        scene.requestGeometryUpdate(.iOS(interfaceOrientations: orientations)) { error in
            #if DEBUG
            print("Interface orientation update failed: \(error.localizedDescription)")
            #endif
        }
    }

    private static var activeScene: UIWindowScene? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
    }

    private static func updateSupportedInterfaceOrientations() {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .forEach { window in
                window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            }
    }
}
