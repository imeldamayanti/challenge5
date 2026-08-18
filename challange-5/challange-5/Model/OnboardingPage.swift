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
    case art(String)
    /// An SF Symbol, for the one screen the Figma board does not draw. See `OnboardingViewModel`.
    case symbol(String)
}
