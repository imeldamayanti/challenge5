//
//  SideQuestWatchNotificationDelegate.swift
//  hisplora Watch App
//

import Foundation
import UIKit
import UserNotifications
import os

private let log = Logger(subsystem: "com.umar.hisplora", category: "watch-notif")

/// What a tap on a sidequest notification resolves to. Three already-decided values, not a
/// `UNNotification` — the same shape `SideQuestLongLookView` and `SideQuestWatchCardView` take, so
/// nothing downstream of here has to know a notification was involved.
struct OpenedSideQuestCard: Identifiable, Sendable {
    let sideQuestID: String
    let synopsis: String
    let heroImage: UIImage?

    var id: String { sideQuestID }
}

/// `s14` Phase 3 — routes a tapped sidequest notification into the watch app.
///
/// Mirrors `SideQuestNotificationDelegate` in the phone target
/// (`challange-5/Service/SideQuestProximityService.swift`) and reads the same three things off the
/// content: `userInfo["sideQuestID"]`, the body, and the first attachment. It resolves more than the
/// phone's does because the phone can look a sidequest up in `ContentKit` and this target cannot —
/// the watch links neither `ContentKit` nor `DesignSystem`, so everything it renders has to arrive
/// in the notification itself.
///
/// Held by `hisplora_Watch_AppApp` in `@State`. `UNUserNotificationCenter.current().delegate` is
/// `weak`, and a delegate nothing retains is one the system silently drops.
final class SideQuestWatchNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {

    var onTap: (@MainActor (OpenedSideQuestCard) -> Void)?

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let content = response.notification.request.content
        log.debug("tap action=\(response.actionIdentifier, privacy: .public)")
        // Every action on this category opens the card, the default tap included — there is only one
        // action, and dismissal arrives as `UNNotificationDismissActionIdentifier`, which is not it.
        if response.actionIdentifier != UNNotificationDismissActionIdentifier,
           let sideQuestID = content.userInfo["sideQuestID"] as? String {
            let card = OpenedSideQuestCard(
                sideQuestID: sideQuestID,
                synopsis: content.body,
                heroImage: SideQuestNotificationController.loadHeroImage(from: content.attachments))
            log.debug("opening card for \(sideQuestID, privacy: .public)")
            Task { @MainActor [onTap] in onTap?(card) }
        }
        completionHandler()
    }

    /// A local notification can fire while the watch app is already foregrounded — the region that
    /// triggers it is monitored by the phone and knows nothing about what the watch is showing.
    /// Mirrors the phone delegate's `[.banner, .sound]`.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
