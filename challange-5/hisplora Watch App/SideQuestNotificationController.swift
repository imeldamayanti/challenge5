//
//  SideQuestNotificationController.swift
//  hisplora Watch App
//

import SwiftUI
import UIKit
import UserNotifications
import WatchKit
import os

/// Same reasoning as the phone side (`s14` D5): a notification that never arrives on a real walk
/// cannot be debugged with `print`, which only exists while Xcode is attached.
private let log = Logger(subsystem: "com.umar.hisplora", category: "watch-notif")

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
        let content = notification.request.content
        log.debug("didReceive category=\(content.categoryIdentifier, privacy: .public) attachments=\(content.attachments.count, privacy: .public)")
        synopsis = Self.synopsis(from: content)
        heroImage = Self.loadHeroImage(from: content.attachments)
    }

    /// `670:1826`/`670:1832` split the copy: the short look is a teaser and the long look prints
    /// the sidequest's own synopsis, so `content.body` is no longer the synopsis and the synopsis
    /// travels in `userInfo` beside the id (`SideQuestProximityService.postNotification`).
    ///
    /// Falls back to the body, which is what a notification from a build that predates the split
    /// carries — those still expand into something readable rather than an empty card.
    ///
    /// Internal rather than `private` for the same reason `loadHeroImage` is: the tap path in
    /// `SideQuestWatchNotificationDelegate` has to read exactly what the long look read.
    static func synopsis(from content: UNNotificationContent) -> String {
        (content.userInfo["synopsis"] as? String) ?? content.body
    }

    /// Best-effort only. `UNNotificationAttachment.url` is a security-scoped URL, and
    /// `startAccessingSecurityScopedResource()` is documented as unreliable specifically on watchOS
    /// (unlike the same pattern on iOS) — Apple Developer Forums threads 713567 and 70104. Any
    /// failure here — the scope not starting, the read failing, corrupt image data — returns `nil`,
    /// which `SideQuestLongLookView` renders as the flat-palette placeholder (`FR-WATCH-06`'s
    /// fallback), not a crash or an empty slot. If the image slot never shows a real photo even once
    /// a sidequest ships `heroImageAsset`, this is why — read the two forum threads before assuming a
    /// bug in this function.
    ///
    /// Internal rather than `private` so `SideQuestWatchNotificationDelegate` can reuse it: the tap
    /// path has to read the same attachment the long look read, and a second copy of a
    /// security-scoped read whose failure modes are this specific would drift from this one.
    static func loadHeroImage(from attachments: [UNNotificationAttachment]) -> UIImage? {
        guard let url = attachments.first?.url else { return nil }
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer { if didStartAccessing { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }
}
