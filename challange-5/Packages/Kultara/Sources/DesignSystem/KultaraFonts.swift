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
    /// Special Elite, shipped with the package. The typebar face of the story preview's sheet
    /// (`81:588`), where the hook is a page coming out of a typewriter. It is a costume face and
    /// belongs to that one object — used anywhere else it is a novelty.
    case typewriter
    /// New York, the system's own serif, which is what the Hisplora frames set their headings in
    /// (`New York Extra Large` on `81:588`, `98:1588`, `187:866`). Kept distinct from `.serif`:
    /// the museum catalogue is set in Instrument Serif and stays that way, and the story flow gets
    /// the face its frames were drawn with. The seam is the same screen boundary the palette uses.
    case displaySerif
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
    /// Special Elite, Apache 2.0 (licence shipped beside the face).
    public static let typewriterName = "SpecialElite-Regular"
    /// Bodoni Moda's Regular PostScript name — what `Font.custom` resolves by. The *file* ships
    /// under a different name (`bodoniResourceName`): it is a variable font whose default instance
    /// is Regular, so the PostScript name and the resource name are not the same string.
    public static let bodoniName = "BodoniModa-Regular"
    /// The variable font's file name inside `Resources/Fonts`, for the lookup only.
    private static let bodoniResourceName = "BodoniModa-Variable"
    /// Shadows Into Light Two, SIL OFL 1.1 (licence shipped beside the face). File name and
    /// PostScript name coincide.
    public static let handwritingName = "ShadowsIntoLightTwo-Regular"

    /// Registration is done once, on first use, and its result is remembered. `static let` gives
    /// the once-only semantics and the thread safety without a lock.
    public static let isAvailable: Bool = register()

    /// The typewriter face separately, because it is a different failure: the serif missing
    /// reflows every heading, while this one missing only costs the sheet its costume. Each falls
    /// back on its own rather than one absence disabling the other.
    public static let typewriterIsAvailable: Bool = registerFace(typewriterName)

    /// Both share-story postcard faces (`921:2654`, `921:2960`), kept apart from the roles above
    /// for the same reason the typewriter is: they are costume faces that belong to the one object
    /// — the shareable story card (`FR-DONE-06`) — and used anywhere else they are a novelty. The
    /// card is a fixed-canvas render, so neither face carries a Dynamic Type fallback size here;
    /// what each caller does when a flag comes back false is the caller's own documented trade.
    ///
    /// Bodoni Moda sets the postcard's printed labels ("POSTCARD", "Memo :", "Duration :") and
    /// Shadows Into Light Two stands in for the walker's handwriting. One flag each, so a missing
    /// engraving face costs the printing and not the handwriting, and the other way round.
    public static let bodoniIsAvailable: Bool = registerFace(bodoniResourceName)
    public static let handwritingIsAvailable: Bool = registerFace(handwritingName)

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

        case .displaySerif:
            // `.italic(_:)` rather than nothing: `journalLetterTitle` is the first display-serif
            // role the frames set leaning, and a role that declares `isItalic` and is then drawn
            // upright is a table that lies about what it decides.
            return .system(role.textStyle, design: .serif, weight: role.weight)
                .italic(role.isItalic)

        case .typewriter:
            guard typewriterIsAvailable else {
                // SF Pro's monospaced design: still a typed page, still the same metrics through
                // Dynamic Type. This was the shipped state before the face was licensed.
                return .system(role.textStyle, design: .monospaced, weight: role.weight)
            }
            return .custom(typewriterName,
                           size: role.basePointSize,
                           relativeTo: role.textStyle)

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

    #if canImport(UIKit)
    /// The UIKit twin of `font(_:)`, for the one thing SwiftUI cannot lay out: justified copy.
    ///
    /// `Text` has no justified alignment and ignores an `NSParagraphStyle`, so a passage set flush
    /// on both edges is laid out by `UILabel` — and a `UILabel` needs a `UIFont`. Every decision is
    /// still read off `KultaraTypography.Role`: the face, the base size, the text style it scales
    /// against, and the same fallbacks `font(_:)` takes when a packaged face is missing. Neither
    /// resolver holds a rule the other does not, which is the point of it living here rather than
    /// at the one call site.
    static func uiFont(_ role: KultaraTypography.Role) -> UIFont {
        let metrics = UIFontMetrics(forTextStyle: role.uiTextStyle)

        switch role.face {
        case .sans:
            return metrics.scaledFont(for: role.uiSystemFont(design: nil))

        case .displaySerif:
            return metrics.scaledFont(for: role.uiSystemFont(design: .serif))

        case .typewriter:
            guard typewriterIsAvailable,
                  let face = UIFont(name: typewriterName, size: role.basePointSize)
            else { return metrics.scaledFont(for: role.uiSystemFont(design: .monospaced)) }
            return metrics.scaledFont(for: face)

        case .serif:
            guard isAvailable,
                  let face = UIFont(name: role.isItalic ? italicName : regularName,
                                    size: role.basePointSize)
            else { return metrics.scaledFont(for: role.uiSystemFont(design: .serif)) }
            return metrics.scaledFont(for: face)
        }
    }
    #endif
}

#if canImport(UIKit)
private extension KultaraTypography.Role {

    /// `Font.TextStyle` and `UIFont.TextStyle` are two spellings of one table, and Swift knows no
    /// conversion between them.
    var uiTextStyle: UIFont.TextStyle {
        switch textStyle {
        case .largeTitle: .largeTitle
        case .title: .title1
        case .title2: .title2
        case .title3: .title3
        case .headline: .headline
        case .subheadline: .subheadline
        case .body: .body
        case .callout: .callout
        case .footnote: .footnote
        case .caption: .caption1
        case .caption2: .caption2
        @unknown default: .body
        }
    }

    /// The system face at this role's style, weight and design — the unscaled base
    /// `UIFontMetrics` then scales, so the reader's text size still reaches it (`NFR-A11Y-01`).
    ///
    /// The italic is applied to the *descriptor* rather than by asking for an italic system font,
    /// because `.serif` and `.italic` are both descriptor traits and asking for one drops the
    /// other.
    func uiSystemFont(design: UIFontDescriptor.SystemDesign?) -> UIFont {
        let size = UIFont.preferredFont(forTextStyle: uiTextStyle).pointSize
        let base = UIFont.systemFont(ofSize: size, weight: uiWeight)
        var descriptor = base.fontDescriptor
        if let design, let designed = descriptor.withDesign(design) { descriptor = designed }
        if isItalic {
            var traits = descriptor.symbolicTraits
            traits.insert(.traitItalic)
            if let italic = descriptor.withSymbolicTraits(traits) { descriptor = italic }
        }
        return UIFont(descriptor: descriptor, size: size)
    }

    /// `Font.Weight` is an opaque `Equatable` struct with no exhaustive case list, so this compares
    /// rather than switches, and falls to regular for anything the table does not name.
    var uiWeight: UIFont.Weight {
        switch weight {
        case .ultraLight: .ultraLight
        case .thin: .thin
        case .light: .light
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        case .heavy: .heavy
        case .black: .black
        default: .regular
        }
    }
}
#endif

private extension Font {
    func italic(_ isItalic: Bool) -> Font { isItalic ? self.italic() : self }
}
