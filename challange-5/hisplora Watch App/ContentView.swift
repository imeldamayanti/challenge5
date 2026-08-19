//
//  ContentView.swift
//  hisplora Watch App
//
//  Created by Imelda Damayanti on 18/08/26.
//

import SwiftUI

/// The watch app's one screen. It shows the sidequest a notification tap opened — `91:182`'s
/// gold-frame card, **not** the `91:176` radar the notification's own long look renders (`s14` D2:
/// the two surfaces are different places and get different designs) — and otherwise says what this
/// app is for.
///
/// There is no navigation and nothing is persisted: `openedCard` lives in `hisplora_Watch_AppApp`'s
/// `@State` and is gone on relaunch. That is the whole of the watch experience as built.
struct ContentView: View {
    let openedCard: OpenedSideQuestCard?

    var body: some View {
        ScrollView {
            if let openedCard {
                SideQuestWatchCardView(
                    synopsis: openedCard.synopsis,
                    heroImage: openedCard.heroImage)
            } else {
                idleScreen
            }
        }
        .sideQuestCardGround()
    }

    /// Not "the watch experience isn't built yet" any more — it is, and this is what a walker sees
    /// when they open the app themselves rather than arriving from a notification. It tells them
    /// what has to happen for anything to appear here.
    private var idleScreen: some View {
        VStack(spacing: 8) {
            Image(systemName: "figure.walk.circle")
                .imageScale(.large)
                .foregroundStyle(Color(hex: 0x804A34))
            Text("Hisplora")
                .font(.headline)
                .foregroundStyle(Color(hex: 0x151311))
            Text("Walk near a place with a story and a card appears here.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color(hex: 0x151311).opacity(0.65))
        }
        .padding()
        // Without this the scroll content is only as wide as the text, the ground painted behind the
        // scroll view is inset to match, and a black band shows down each edge — 25px a side on a
        // 46 mm simulator. `SideQuestWatchCardView` already carries its own `maxWidth: .infinity`,
        // which is why only this branch showed it.
        .frame(maxWidth: .infinity)
    }
}

#Preview("Idle") {
    ContentView(openedCard: nil)
}

#Preview("Opened from a notification") {
    ContentView(openedCard: OpenedSideQuestCard(
        sideQuestID: "sq-park23",
        synopsis: "You're on a battlefield. The last tale of Badung.",
        heroImage: nil))
}
