//
//  ASMR_Walk_Route_OverlayApp.swift
//  ASMR Walk Route Overlay
//
//  Created by David Heath on 9/5/26.
//

import AppKit
import SwiftUI

@main
struct ASMR_Walk_Route_OverlayApp: App {
    @NSApplicationDelegateAdaptor(OverlayApplicationDelegate.self) private var applicationDelegate

    var body: some Scene {
        Window("ASMR Walk Route Overlay", id: "registration") {
            ContentView()
        }
    }
}

@MainActor
final class OverlayApplicationDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(applicationTerminated(_:)),
            name: NSWorkspace.didTerminateApplicationNotification, object: nil
        )
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    @objc private func applicationTerminated(_ notification: Notification) {
        guard let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              application.bundleIdentifier == "com.bald-traveler.ASMR-Walk-Mac-Importer" else { return }
        // Only the registration helper exits; the host owns the FxPlug service.
        NSApplication.shared.terminate(nil)
    }
}
