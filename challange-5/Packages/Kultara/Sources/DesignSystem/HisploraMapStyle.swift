import SwiftUI

/// Cartographic tokens, stroke styles and visual constants for the Hisplora vintage Balinese heritage map.
///
/// Designed to recreate the look of a hand-drawn 19th/early 20th century expedition & heritage map
/// printed on aged Balinese parchment.
public struct HisploraMapStyle: Sendable, Equatable {

    // MARK: - Cartographic Colors (SRGB)

    public static let parchmentGround = SRGBColor(hex: "#F4EBD9")
    public static let parchmentWarm = SRGBColor(hex: "#EFE3CA")
    public static let parchmentSunken = SRGBColor(hex: "#E5D6BD")
    public static let parchmentBorder = SRGBColor(hex: "#D5C1A3")

    public static let roadCasing = SRGBColor(hex: "#3C2A21")
    public static let roadCasingMinor = SRGBColor(hex: "#5A4438")
    public static let roadFill = SRGBColor(hex: "#FAF7EE")
    public static let roadFillMinor = SRGBColor(hex: "#F2EBE0")

    public static let riverFill = SRGBColor(hex: "#7FA0A9")
    public static let riverCasing = SRGBColor(hex: "#567680")
    public static let riverHatching = SRGBColor(hex: "#4E6B74")

    public static let parkWash = SRGBColor(hex: "#687158")
    public static let parkBorder = SRGBColor(hex: "#515A43")

    public static let compoundWash = SRGBColor(hex: "#EAE0CE")
    public static let compoundBorder = SRGBColor(hex: "#4A3B32")

    public static let parcelLine = SRGBColor(hex: "#8C7A6B")
    public static let parcelLineFaint = SRGBColor(hex: "#B09E8F")

    public static let routeInk = SRGBColor(hex: "#9C2E1F")
    public static let routeInkMuted = SRGBColor(hex: "#B54F42")

    public static let markerUncompleted = SRGBColor(hex: "#4A3B32")
    public static let markerActive = SRGBColor(hex: "#A33020")
    public static let markerCompleted = SRGBColor(hex: "#2E523A")

    public static let goldStamp = SRGBColor(hex: "#C48A2C")
    public static let inkText = SRGBColor(hex: "#2C1E18")
    public static let inkTextMuted = SRGBColor(hex: "#5A4438")

    // MARK: - Landmark Calligraphy & Reference Sketch Tokens
    public static let pemecutanNavy = SRGBColor(hex: "#2D4C6B")
    public static let puputanGreen = SRGBColor(hex: "#295C38")
    public static let sketchCircleGreen = SRGBColor(hex: "#4C7456")
    public static let transitBadgeBg = SRGBColor(hex: "#5A7285")

    // MARK: - Stroke Styles

    public static let roadMajorCasingWidth: CGFloat = 3.6
    public static let roadMajorFillWidth: CGFloat = 2.4

    public static let roadSecondaryCasingWidth: CGFloat = 2.6
    public static let roadSecondaryFillWidth: CGFloat = 1.6

    public static let roadMinorCasingWidth: CGFloat = 1.6
    public static let roadMinorFillWidth: CGFloat = 1.0

    public static let riverWidth: CGFloat = 5.0
    public static let riverBorderWidth: CGFloat = 1.0

    public static let routeStrokeStyle = StrokeStyle(
        lineWidth: 2.8,
        lineCap: .round,
        lineJoin: .round,
        dash: [6, 4]
    )

    public static let parcelStrokeStyle = StrokeStyle(
        lineWidth: 0.6,
        lineCap: .butt,
        lineJoin: .miter,
        dash: [4, 2]
    )

    public static let boundaryStrokeStyle = StrokeStyle(
        lineWidth: 1.2,
        lineCap: .round,
        lineJoin: .round,
        dash: [8, 3, 2, 3]
    )
}
