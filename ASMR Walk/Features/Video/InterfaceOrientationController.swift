//
//  InterfaceOrientationController.swift
//  ASMR Walk
//

import UIKit

@MainActor
enum InterfaceOrientationController {
    static func request(_ orientations: UIInterfaceOrientationMask) {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else {
            return
        }

        scene.requestGeometryUpdate(.iOS(interfaceOrientations: orientations))
    }
}
