//
//  SideQuestNotificationController.swift
//  hisplora Watch App
//

import SwiftUI
import UIKit
import UserNotifications
import WatchKit

/// `s9` Phase B, `FR-WATCH-05` — hosts `SideQuestLongLookView` for the `"sidequest-nearby"` category,
/// registered as a `WKNotificationScene` in `hisploraApp.swift`. `didReceive(_:)` resolves everything
/// once, synchronously, so `body` never redoes the (best-effort, see `loadHeroImage`) attachment read.
final class SideQuestNotificationController: WKUserNotificationHostingController<SideQuestLongLookView> {

    private var synopsis: String = ""
    private var heroImage: UIImage?

    override var body: SideQuestLongLookView {
        SideQuestLongLookView(synopsis: synopsis, heroImage: heroImage)
    }

    override func didReceive(_ notification: UNNotification) {
        #if DEBUG
        print("[watch-notif] didReceive: category=\(notification.request.content.categoryIdentifier), "
            + "title=\(notification.request.content.title), attachments="
            + "\(notification.request.content.attachments.count)")
        #endif
        synopsis = notification.request.content.body
        heroImage = Self.loadHeroImage(from: notification.request.content.attachments)
    }

    /// Best-effort only. `UNNotificationAttachment.url` is a security-scoped URL, and
    /// `startAccessingSecurityScopedResource()` is documented as unreliable specifically on watchOS
    /// (unlike the same pattern on iOS) — Apple Developer Forums threads 713567 and 70104. Any
    /// failure here — the scope not starting, the read failing, corrupt image data — returns `nil`,
    /// which `SideQuestLongLookView` renders as the flat-palette placeholder (`FR-WATCH-06`'s
    /// fallback), not a crash or an empty slot. If the image slot never shows a real photo even once
    /// a sidequest ships `heroImageAsset`, this is why — read the two forum threads before assuming a
    /// bug in this function.
    private static func loadHeroImage(from attachments: [UNNotificationAttachment]) -> UIImage? {
        guard let url = attachments.first?.url else { return nil }
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer { if didStartAccessing { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }
}
