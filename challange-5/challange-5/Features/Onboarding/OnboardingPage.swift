import Foundation
import UIStringsKit

struct OnboardingPage: Sendable, Identifiable {
    let id: Int
    let titleKey: UIStringKey
    let bodyKey: UIStringKey
    let illustration: OnboardingIllustration
}

/// Which picture a page carries, named rather than resolved.
///
/// The same move `LoreBlockPresentation.Ink` makes, for the same reason: a presentation type that
/// held a `DesignSystem` image would be a presentation type holding a piece of the design system,
/// and the `Sendable`-value-types-only rule on `Model/` exists precisely to make that impossible.
/// The view does the lookup.
enum OnboardingIllustration: Sendable, Equatable {
    /// One of the three exported Figma artworks, by `HisploraOnboardingArt`'s own case name.
    ///
    /// The only case. There used to be a `symbol` beside it, for the one screen the Figma board did
    /// not draw — the pocket-the-phone screen, removed 2026-08-20 (see `OnboardingViewModel` on
    /// what that costs). It went with the screen rather than being left as an unreachable case that
    /// reads like a supported option.
    case art(String)
}
