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

    /// Which sidequest a *proximity event* announced — a notification tap, or a region firing
    /// while the app is open.
    ///
    /// **Deliberately not the same field as `pendingSideQuestID`, because the two are different
    /// journeys.** A walker who taps a row in the nearby list has chosen to do a sidequest and
    /// gets `SideQuestFlowView`: the notice, the story, the challenge. A walker who simply walked
    /// past one gets `1108:2780`'s New Discovery card and, if they want it, `949:2461`'s page —
    /// something happened *at* them, and the first screen says what happened rather than what to
    /// do about it. Folding both into one field means one of the two journeys silently becomes
    /// the other.
    var discoveredSideQuestID: String?
}
