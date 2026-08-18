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
/// identical to the phone copy; a mismatch here means the watch's own
/// registration (harmless today, load-bearing once Phase B's
/// `WKNotificationScene` binds to this category) silently disagrees with what
/// the phone's notification requests carry.
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
