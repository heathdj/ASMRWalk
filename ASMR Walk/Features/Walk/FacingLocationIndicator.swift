//
//  FacingLocationIndicator.swift
//  ASMR Walk
//

import CoreLocation
import SwiftUI

struct FacingLocationIndicator: View {
    let headingDegrees: CLLocationDirection?

    var body: some View {
        ZStack {
            if let headingDegrees {
                Image(systemName: "location.north.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.blue)
                    .rotationEffect(.degrees(headingDegrees))
                    .shadow(radius: 2)
            } else {
                Circle()
                    .fill(.blue)
                    .frame(width: 18, height: 18)
                    .overlay {
                        Circle()
                            .stroke(.white, lineWidth: 3)
                    }
                    .shadow(radius: 2)
            }
        }
        .accessibilityLabel("Current location and facing direction")
    }
}
