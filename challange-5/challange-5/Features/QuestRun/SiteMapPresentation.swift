import Foundation

/// The drawn plan of a Place's grounds, resolved for the site-map screen (`452:3028`).
///
/// **The citation is not optional and is not a separate lookup.** A site plan asserts where the gates
/// are and how far apart the walls stand, which `FR-CP-05` treats as a claim like any other — so the
/// asset and its provenance are one value, and a screen that has the drawing necessarily has the
/// words about it. Resolving the citation here rather than in the view is also what keeps the view
/// out of `ContentRepository`: the model is a snapshot, the same as every other type in `Model/`.
///
/// `markers` are fractions of the image, `{0,0}` top-left — the same convention `MapPoint` uses on
/// the region map, and for the same reason: the plan is a drawing, so a marker's place on it is a
/// drawing decision and never a projection of a real coordinate.
struct SiteMapPresentation: Sendable, Equatable {
    let imageURL: URL?
    let aspectRatio: Double
    /// The Place's own `Source.citation` for the plan. Today's shipped plan is a generated
    /// illustration and its citation says so, beginning `BELUM DIVERIFIKASI` — which is exactly what
    /// this field exists to put on the screen rather than leave in a JSON file.
    let citation: String
    let markers: [SiteMapMarker]
}

/// One marked point on the plan.
struct SiteMapMarker: Sendable, Equatable, Identifiable {
    let id: Int
    let x: Double
    let y: Double
}

/// The drawn map of the streets around a Place, resolved for the Location Verified screen
/// (`1:4458`).
///
/// **It carries no citation, unlike `SiteMapPresentation`, and that is the open half of the
/// decision recorded on `ApproachMapView`.** The authored `sourceRef` is still there and still
/// enforced by V3 and V14; the screen does not print it, so there is nothing for this model to hand
/// over. Restoring the line means adding the field back here and reading it in the view — the
/// resolver already has the Place's sources in hand.
struct ApproachMapPresentation: Sendable, Equatable {
    let imageURL: URL?
    let aspectRatio: Double
}
