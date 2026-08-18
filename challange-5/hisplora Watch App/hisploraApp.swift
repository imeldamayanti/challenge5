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
    }
}

/// Mirrors `SideQuestNotificationCategory` in the phone target
/// (`challange-5/Service/SideQuestProximityService.swift`) — the two targets
/// don't share a module for one string constant, so this is a deliberate
/// duplication. Keep `identifier` and `openInAppActionIdentifier` byte-for-byte
/// identical to the phone copy; a mismatch here would leave this registration
/// disagreeing with what the phone's notification requests carry.
///
/// Whether this registration is load-bearing for Phase B is an open question, not a settled fact:
/// for a *forwarded* notification (the mechanism until Phase B builds a real watch-native
/// scheduling path), the action set the watch shows may come from the iPhone's category
/// registration rather than this one, in which case this copy could stay inert even once
/// `WKNotificationScene` exists. `s9` §3 already flags the exact `WKNotificationScene`/dynamic-
/// interface API surface as unverified for the installed watchOS 26 SDK — resolve this there
/// before Phase B is built, rather than assuming either direction here.
enum WatchSideQuestNotificationCategory {
    static let identifier = "sidequest-nearby"
    static let openInAppActionIdentifier = "OPEN_IN_APP"

    static func register() {
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
