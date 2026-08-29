//
//  ContentView.swift
//  ASMRWalk Watch App
//
//  Created by David Heath on 8/29/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "figure.walk.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.green)

            Text("ASMR Walk")
                .font(.headline)

            Text("Watch recording setup")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ContentView()
}
