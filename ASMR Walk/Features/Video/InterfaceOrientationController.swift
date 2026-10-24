//
//  InterfaceOrientationController.swift
//  ASMR Walk
//

import UIKit

final class AppOrientationDelegate: NSObject, UIApplicationDelegate {
    static var supportedOrientations: UIInterfaceOrientationMask = .portrait

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(
            name: nil,
            sessionRole: connectingSceneSession.role
        )
        if connectingSceneSession.role == .windowApplication {
            configuration.delegateClass = AppOrientationSceneDelegate.self
        }
        return configuration
    }

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        Self.supportedOrientations
    }
}

final class AppOrientationSceneDelegate: NSObject, UIWindowSceneDelegate {
    func supportedInterfaceOrientations(for windowScene: UIWindowScene) -> UIInterfaceOrientationMask {
        AppOrientationDelegate.supportedOrientations
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
        preparePolicy(for: tab)
        request(AppOrientationPolicy.orientationMask(for: tab))
    }

    static func requestPolicyAndWait(for tab: AppTab) async {
        let orientationMask = AppOrientationPolicy.orientationMask(for: tab)
        preparePolicy(for: tab)
        request(orientationMask)

        guard let scene = activeScene else {
            return
        }

        for _ in 0..<180 {
            if matches(orientationMask, orientation: scene.effectiveGeometry.interfaceOrientation) {
                return
            }
            guard Task.isCancelled == false else {
                return
            }
            try? await Task.sleep(for: .milliseconds(16))
        }
    }

    static func preparePolicy(for tab: AppTab) {
        let orientationMask = AppOrientationPolicy.orientationMask(for: tab)
        AppOrientationDelegate.supportedOrientations = orientationMask
        updateSupportedInterfaceOrientations()
    }

    private static func matches(
        _ orientationMask: UIInterfaceOrientationMask,
        orientation: UIInterfaceOrientation
    ) -> Bool {
        switch orientation {
        case .portrait:
            orientationMask.contains(.portrait)
        case .portraitUpsideDown:
            orientationMask.contains(.portraitUpsideDown)
        case .landscapeLeft:
            orientationMask.contains(.landscapeLeft)
        case .landscapeRight:
            orientationMask.contains(.landscapeRight)
        case .unknown:
            false
        @unknown default:
            false
        }
    }

    private static func request(_ orientations: UIInterfaceOrientationMask) {
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
