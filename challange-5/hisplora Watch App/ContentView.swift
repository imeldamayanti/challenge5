//
//  ContentView.swift
//  hisplora Watch App
//
//  Created by Imelda Damayanti on 18/08/26.
//

import SwiftUI

/// Phase A's placeholder for the watch companion (`s9` Phase A) — honest about being unbuilt
/// rather than shipping Xcode's unedited template. This is not Phase B's real watch experience;
/// it is what a walker sees if the watch app is opened before Phase B exists. See
/// `.claude/plans/sidequest/s9-watch-notification-scene.plan.md`.
struct ContentView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "figure.walk.circle")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hisplora")
                .font(.headline)
            Text("The watch experience isn't built yet.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
