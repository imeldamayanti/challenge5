//
//  hisploraApp.swift
//  hisplora Watch App
//
//  Created by Imelda Damayanti on 18/08/26.
//

import SwiftUI
import UserNotifications

@main
struct hisplora_Watch_AppApp: App {
    /// Held here rather than constructed inline: `UNUserNotificationCenter.current().delegate` is
    /// `weak`, so a delegate nothing retains is one the system drops without saying so. The phone
    /// target documents the same pattern in `challange_5App.swift`; this follows it.
    @State private var notificationDelegate = SideQuestWatchNotificationDelegate()
    /// The sidequest a tap opened, or `nil` for the idle screen.
    @State private var openedCard: OpenedSideQuestCard?

    init() {
        WatchSideQuestNotificationCategory.register()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(openedCard: openedCard)
                .onAppear {
                    notificationDelegate.onTap = { openedCard = $0 }
                    UNUserNotificationCenter.current().delegate = notificationDelegate
                }
        }
        WKNotificationScene(
            controller: SideQuestNotificationController.self,
            category: WatchSideQuestNotificationCategory.identifier)
    }
}

/// Mirrors `SideQuestNotificationCategory` in the phone target
/// (`challange-5/Service/SideQuestProximityService.swift`) — the two targets
/// don't share a module for one string constant, so this is a deliberate
/// duplication. Keep `identifier` and `openInAppActionIdentifier` byte-for-byte
/// identical to the phone copy; a mismatch here would leave this registration
/// disagreeing with what the phone's notification requests carry.
///
/// Scene binding for the custom long-look is a **static `Scene` declaration** — the
/// `WKNotificationScene` registered in `hisplora_Watch_AppApp.body` — matched against the forwarded
/// notification's `categoryIdentifier`, independent of either side's `setNotificationCategories`
/// call. Both this registration and the phone's (Phase A, `SideQuestProximityService.swift`) stay
/// necessary for the action set each side renders, but neither one is what makes the custom long-look
/// card appear; the `WKNotificationScene` declaration is.
enum WatchSideQuestNotificationCategory {
    static let identifier = "sidequest-nearby"
    static let openInAppActionIdentifier = "OPEN_IN_APP"

    static func register() {
        // `.foreground`, and it launches *this* app — the watch one. There is no relay: a
        // `UNNotificationAction`'s options are evaluated by whichever device handles the tap, and
        // once this target's `WKNotificationScene` claims `"sidequest-nearby"` the watch renders
        // the long look and handles every tap on it. The phone's own registration
        // (`SideQuestProximityService.swift`), which does carry `.foreground`, never gets a say.
        //
        // An earlier comment here claimed the empty option set would "relay back to the phone's own
        // registration". It does not, and with `options: []` the tap dismissed the notification and
        // did nothing at all. `s12` established this and `s14` Phase 3 re-applies the fix; waking
        // the iPhone from here is `FR-WATCH-07`, which stays open and unsatisfiable as written.
        let openInApp = UNNotificationAction(
            identifier: openInAppActionIdentifier,
            title: "Open in App",
            options: [.foreground])
        let category = UNNotificationCategory(
            identifier: identifier,
            actions: [openInApp],
            intentIdentifiers: [],
            options: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }
}
