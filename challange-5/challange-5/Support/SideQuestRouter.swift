import Foundation

/// Which sidequest to present, set from outside the navigation stacks — a notification tap or a
/// foreground region entry (`s3`), neither of which has a stack to push onto.
///
/// A reference type owned above `KultaraRootView`, rather than the view's own `@State`, because
/// `challange_5App`'s notification delegate and `SystemProximityMonitor.onSideQuestNearby` both
/// need to reach it and neither lives inside the view hierarchy.
@MainActor
@Observable
final class SideQuestRouter {
    var pendingSideQuestID: String?
}
