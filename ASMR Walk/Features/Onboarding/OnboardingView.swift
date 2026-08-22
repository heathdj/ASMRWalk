//
//  OnboardingView.swift
//  ASMR Walk
//

import SwiftUI

enum OnboardingCompletion {
    static let storageKey = "hasCompletedOnboarding"
}

struct OnboardingView: View {
    @AppStorage(OnboardingCompletion.storageKey) private var hasCompletedOnboarding = false
    @State private var selectedPage = OnboardingPage.walk

    private let pages = OnboardingPage.allCases

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $selectedPage) {
                ForEach(pages) { page in
                    OnboardingPageView(page: page)
                        .tag(page)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            VStack(spacing: 12) {
                Button(primaryButtonTitle, systemImage: primaryButtonSystemImage) {
                    advanceOrComplete()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier(AccessibilityID.onboardingPrimaryButton)

                Button("Skip Tour") {
                    hasCompletedOnboarding = true
                }
                .buttonStyle(.borderless)
                .accessibilityIdentifier(AccessibilityID.onboardingSkipButton)
            }
            .padding()
        }
        .tint(.green)
        .accessibilityIdentifier(AccessibilityID.onboardingScreen)
    }

    private var primaryButtonTitle: String {
        selectedPage == pages.last ? "Start Using ASMR Walk" : "Next"
    }

    private var primaryButtonSystemImage: String {
        selectedPage == pages.last ? "checkmark.circle.fill" : "arrow.right.circle.fill"
    }

    private func advanceOrComplete() {
        guard let currentIndex = pages.firstIndex(of: selectedPage) else {
            hasCompletedOnboarding = true
            return
        }

        let nextIndex = pages.index(after: currentIndex)

        if nextIndex == pages.endIndex {
            hasCompletedOnboarding = true
        } else {
            withAnimation(.snappy) {
                selectedPage = pages[nextIndex]
            }
        }
    }
}

private enum OnboardingPage: CaseIterable, Identifiable {
    case walk
    case videoWalk
    case history
    case deleteHistory
    case backgroundGPS

    var id: Self { self }

    var title: String {
        switch self {
        case .walk:
            "Walk"
        case .videoWalk:
            "Video Walk"
        case .history:
            "History"
        case .deleteHistory:
            "Deleting Walks"
        case .backgroundGPS:
            "Background GPS"
        }
    }

    var subtitle: String {
        switch self {
        case .walk:
            "Record a GPS route when you want the simple walking journal: time, distance, and a clean map trail."
        case .videoWalk:
            "Capture video while ASMR Walk tracks the route beside it. Finished videos stay in the app, and you can save a copy to Photos from History."
        case .history:
            "Review saved walks, replay routes on the map, watch video walks, and export GPX files when you need the route elsewhere."
        case .deleteHistory:
            "To remove a walk from History, swipe left on it and tap Delete. A confirmation will appear before anything is permanently removed."
        case .backgroundGPS:
            "GPS walks keep recording even when you leave the app. Enable \"Always\" location access in Settings → Privacy & Security → Location Services → ASMR Walk to ensure your route is captured the whole way."
        }
    }

    var systemImage: String {
        switch self {
        case .walk:
            "figure.walk"
        case .videoWalk:
            "video.fill"
        case .history:
            "clock.arrow.circlepath"
        case .deleteHistory:
            "trash.circle"
        case .backgroundGPS:
            "location.circle"
        }
    }

    var accentStyle: Color {
        switch self {
        case .walk:
            .green
        case .videoWalk:
            .blue
        case .history:
            .indigo
        case .deleteHistory:
            .red
        case .backgroundGPS:
            .teal
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .walk:
            AccessibilityID.onboardingWalkPage
        case .videoWalk:
            AccessibilityID.onboardingVideoWalkPage
        case .history:
            AccessibilityID.onboardingHistoryPage
        case .deleteHistory:
            AccessibilityID.onboardingDeleteHistoryPage
        case .backgroundGPS:
            AccessibilityID.onboardingBackgroundGPSPage
        }
    }
}

private struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 24)

            Image(systemName: page.systemImage)
                .font(.system(size: 72, weight: .semibold))
                .foregroundStyle(page.accentStyle)
                .frame(width: 128, height: 128)
                .background(page.accentStyle.opacity(0.12), in: .circle)
                .accessibilityHidden(true)

            VStack(spacing: 14) {
                Text(page.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text(page.subtitle)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 28)
            .accessibilityElement(children: .combine)

            Spacer(minLength: 24)
        }
        .padding(.vertical)
        .accessibilityIdentifier(page.accessibilityIdentifier)
    }
}

#Preview {
    OnboardingView()
}
