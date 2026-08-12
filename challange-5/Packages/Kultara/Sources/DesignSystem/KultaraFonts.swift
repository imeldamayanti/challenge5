import CoreText
import Foundation
import SwiftUI

/// The two faces the theme is set in.
///
/// The reference is a museum longread: a display serif for anything that names something — the
/// masthead, a section's name, an exhibit's title — and the platform's own sans for everything a
/// reader has to actually read or operate. Mixing them is the whole look; using the serif for body
/// copy would be a pastiche of it, and Instrument Serif is a display cut with a small x-height that
/// stops being comfortable somewhere around a paragraph.
public enum KultaraFace: String, Sendable, CaseIterable {
    /// Instrument Serif, shipped with the package.
    case serif
    /// SF Pro — the system face, so it stays in step with the platform's own metrics and with
    /// whatever the reader has done to their text size.
    case sans
}

/// Loads and resolves the packaged typeface.
///
/// The faces are registered at runtime from `Bundle.module` instead of being declared in the app
/// target's `Info.plist`, because `DesignSystem` is a package: a host target that forgets the
/// `UIAppFonts` entry would get a silent fallback to the system serif, and a silent fallback is the
/// kind of thing that ships. `isAvailable` makes that case explicit and testable instead.
public enum KultaraFonts {

    public static let regularName = "InstrumentSerif-Regular"
    public static let italicName = "InstrumentSerif-Italic"

    /// Registration is done once, on first use, and its result is remembered. `static let` gives
    /// the once-only semantics and the thread safety without a lock.
    public static let isAvailable: Bool = register()

    private static func register() -> Bool {
        [regularName, italicName].allSatisfy(registerFace)
    }

    private static func registerFace(_ name: String) -> Bool {
        guard let url = Bundle.module.url(
                forResource: name, withExtension: "ttf", subdirectory: "Fonts"),
              let data = try? Data(contentsOf: url),
              let provider = CGDataProvider(data: data as CFData),
              let font = CGFont(provider)
        else { return false }

        var error: Unmanaged<CFError>?
        let registered = CTFontManagerRegisterGraphicsFont(font, &error)
        // Registering a face twice in one process is not a failure — it happens whenever a test
        // bundle and the app both touch the theme — so the already-registered case counts as
        // available.
        if let error {
            let code = CFErrorGetCode(error.takeRetainedValue())
            return code == CTFontManagerError.alreadyRegistered.rawValue
        }
        return registered
    }

    /// The font for a role, at the role's own size, scaled by the reader's text-size setting.
    ///
    /// `Font.custom(_:size:relativeTo:)` is what carries a bundled face through Dynamic Type
    /// (`NFR-A11Y-01`). It needs a base size, which is why `KultaraTypography.Role` has one — but
    /// that size stays inside the role table. There is still no public API here that lets a call
    /// site name a point size of its own.
    static func font(_ role: KultaraTypography.Role) -> Font {
        switch role.face {
        case .sans:
            return .system(role.textStyle, design: .default, weight: role.weight)

        case .serif:
            guard isAvailable else {
                // New York rather than SF Pro: if the packaged face is missing, the layout was
                // drawn for a serif and a sans substitute would reflow every heading.
                return .system(role.textStyle, design: .serif, weight: role.weight)
                    .italic(role.isItalic)
            }
            return .custom(role.isItalic ? italicName : regularName,
                           size: role.basePointSize,
                           relativeTo: role.textStyle)
        }
    }
}

private extension Font {
    func italic(_ isItalic: Bool) -> Font { isItalic ? self.italic() : self }
}
