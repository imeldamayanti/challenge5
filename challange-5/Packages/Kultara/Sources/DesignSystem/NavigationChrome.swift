#if canImport(UIKit)
import SwiftUI
import UIKit

/// The navigation bar is the one surface SwiftUI still styles with system defaults, and a
/// proportional bold title above a page set in monospace is exactly the seam the theme is meant not
/// to have. This is the UIKit appearance proxy doing what `kultaraFont` does everywhere else.
///
/// Re-applied from `KultaraThemeProvider.body`, so it follows both the colour scheme and the
/// content size category: the fonts below are resolved at their current scaled size rather than
/// frozen at launch (`NFR-A11Y-01`).
enum KultaraNavigationChrome {

    static func apply(_ palette: KultaraPalette) {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = UIColor(palette.paper.color)

        let ink = UIColor(palette.ink.color)
        appearance.titleTextAttributes = [
            .foregroundColor: ink,
            .font: typed(.headline, weight: .semibold),
            .kern: 1.5,
        ]
        // No `largeTitleTextAttributes`: screens set their own heading on the page and their bar
        // title inline, so a large title is a state the app does not enter. Styling one here also
        // costs a real bug — a monospaced, kerned large title lays out to nothing behind a
        // `.principal` toolbar item, and the quest list's name simply disappeared.

        let bar = UINavigationBar.appearance()
        bar.standardAppearance = appearance
        bar.scrollEdgeAppearance = appearance
        bar.compactAppearance = appearance
        bar.tintColor = UIColor(palette.seal.color)
    }

    /// The system's current *scaled* size for the style, re-cut in the monospaced face. Reading the
    /// scaled size and then scaling it again through `UIFontMetrics` would double-count the user's
    /// text-size setting, which at the accessibility sizes is the difference between a large title
    /// and an unreadable one.
    private static func typed(_ style: UIFont.TextStyle, weight: UIFont.Weight) -> UIFont {
        UIFont.monospacedSystemFont(
            ofSize: UIFont.preferredFont(forTextStyle: style).pointSize,
            weight: weight)
    }
}
#endif
