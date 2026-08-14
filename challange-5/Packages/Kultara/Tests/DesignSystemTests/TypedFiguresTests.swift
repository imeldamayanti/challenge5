import SwiftUI
import Testing
@testable import DesignSystem

/// The figures ruled onto the typed sheet. The view itself needs a render to assert, but the two
/// things that would silently go wrong are values: what makes one figure distinct from another in a
/// `ForEach`, and which type role carries the name beside the number.
@Suite("Typed figures")
struct TypedFiguresTests {

    /// Two figures on the same sheet can share a value — "1.5 Hours" of walking and "1.5 Hours"
    /// open — and two on different sheets can share a label. Identity keyed on either half alone
    /// collapses the row to one cell, silently, with no error anywhere.
    @Test func figuresAreDistinguishedByLabelAndValueTogether() {
        let distance = KultaraTypedFigure(label: "Distance", value: "2.2 km")
        let sameValue = KultaraTypedFigure(label: "Estimated Time", value: "2.2 km")
        let sameLabel = KultaraTypedFigure(label: "Distance", value: "1.5 hours")

        #expect(distance.id != sameValue.id)
        #expect(distance.id != sameLabel.id)
        #expect(distance.id == KultaraTypedFigure(label: "Distance", value: "2.2 km").id)
    }

    /// An unlabelled figure is a real state — `35:455` draws the pair that way — and must not
    /// collide with a labelled one carrying the same number.
    @Test func anUnlabelledFigureIsDistinctFromALabelledOne() {
        #expect(KultaraTypedFigure(value: "2.2 km").id
            != KultaraTypedFigure(label: "Distance", value: "2.2 km").id)
    }

    /// The name beside the figure is apparatus, and apparatus is set in the sans — the split the
    /// whole type system runs on. Setting it in the typebar face would make the label read as
    /// something typed onto the page, which is exactly what it is not.
    @Test func theFigureIsTypedAndItsNameIsNot() {
        #expect(KultaraTypography.Role.typedFigure.face == .typewriter)
        #expect(KultaraTypography.Role.caption.face == .sans)
    }
}
