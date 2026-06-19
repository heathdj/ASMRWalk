//
//  StartupSplashView.swift
//  ASMR Walk
//

import SwiftUI

struct RootView: View {
    @State private var isShowingSplash: Bool

    init() {
        _isShowingSplash = State(initialValue: ProcessInfo.processInfo.arguments.contains("--skip-startup-splash") == false)
    }

    var body: some View {
        ZStack {
            ContentView()
                .opacity(isShowingSplash ? 0 : 1)

            if isShowingSplash {
                StartupSplashView()
                    .transition(.opacity)
            }
        }
        .task {
            guard isShowingSplash else {
                return
            }

            try? await Task.sleep(for: .milliseconds(900))
            withAnimation(.easeOut(duration: 0.3)) {
                isShowingSplash = false
            }
        }
    }
}

struct StartupSplashView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    .green.opacity(0.95),
                    .mint.opacity(0.8),
                    .black.opacity(0.9)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                Image(systemName: "figure.walk.circle.fill")
                    .font(.system(size: 88, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white)
                    .accessibilityHidden(true)

                VStack(spacing: 6) {
                    Text("ASMR Walk")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))

                    Text("Record the route. Remember the walk.")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.82))
                }
                .foregroundStyle(.white)

                ProgressView()
                    .tint(.white)
                    .controlSize(.large)
                    .padding(.top, 8)
                    .accessibilityLabel("Loading ASMR Walk")
            }
            .padding(32)
            .accessibilityElement(children: .combine)
        }
        .accessibilityIdentifier(AccessibilityID.startupSplash)
    }
}

#Preview {
    StartupSplashView()
}
