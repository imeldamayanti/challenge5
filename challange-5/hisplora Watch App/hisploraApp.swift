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
    init() {
        WatchSideQuestNotificationCategory.register()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
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
        // `.foreground` here would launch *this* (the watch) app, since the long-look card is
        // hosted locally by `WKNotificationScene` — the button is meant to wake the iPhone, not
        // the watch. Leaving this action's options empty lets the tap relay back to the phone's
        // own `SideQuestNotificationCategory` registration (`SideQuestProximityService.swift`),
        // which does carry `.foreground` for exactly that phone-side launch.
        let openInApp = UNNotificationAction(
            identifier: openInAppActionIdentifier,
            title: "Open in App",
            options: [])
        let category = UNNotificationCategory(
            identifier: identifier,
            actions: [openInApp],
            intentIdentifiers: [],
            options: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }
}
