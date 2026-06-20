//
//  InterfaceOrientationController.swift
//  ASMR Walk
//

import UIKit

@MainActor
enum InterfaceOrientationController {
    static var currentInterfaceOrientation: UIInterfaceOrientation {
        activeScene?.effectiveGeometry.interfaceOrientation ?? .landscapeRight
    }

    static func request(_ orientations: UIInterfaceOrientationMask) {
        guard let scene = activeScene else {
            return
        }

        scene.requestGeometryUpdate(.iOS(interfaceOrientations: orientations))
    }

    private static var activeScene: UIWindowScene? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
    }
}
