//
//  ASMRWalkMacImporterApp.swift
//  ASMR Walk Mac Importer
//

import SwiftUI

@main
struct ASMRWalkMacImporterApp: App {
    var body: some Scene {
        WindowGroup {
            MacImporterView()
        }
        .windowResizability(.contentSize)
    }
}
