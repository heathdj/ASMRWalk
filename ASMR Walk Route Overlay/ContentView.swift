//
//  ContentView.swift
//  ASMR Walk Route Overlay
//
//  Created by David Heath on 9/5/26.
//

import AppKit
import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("ASMR Walk Route Overlay", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 8) {
                Label("FxPlug generator installed", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Open Motion or Final Cut Pro to use the ASMR Walk generator.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Spacer()
                Button("Close") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .frame(minWidth: 420, alignment: .leading)
        .padding(28)
    }
}
