//
//  ContentView.swift
//  ASMR Walk Route Overlay
//
//  Created by David Heath on 9/5/26.
//

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
                Text("Open Motion or Final Cut Pro to use the ASMR Walk generator after this app has been built and launched.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(minWidth: 420, alignment: .leading)
        .padding(28)
    }
}
