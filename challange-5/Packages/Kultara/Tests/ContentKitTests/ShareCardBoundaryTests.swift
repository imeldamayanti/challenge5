import Foundation
import Testing

/// What may and may not appear on a recap card. `FR-DONE-06`, `NFR-PRIV-02`, `AD-4`, `c2` phase 5.
///
/// The card is the one artefact in this app **designed to leave the device entirely** and be
/// forwarded to people who will never install it. So the two rules it has to hold are stronger
/// versions of rules that already apply everywhere else, and both are checked by reading the source
/// rather than by reviewing it.
///
/// Phase 5 is built and switched off (`ShareCardMinting.isAvailable` is `false`, and
/// `supabase/functions/share/` is written and not deployed). These guards exist so that the day it
/// is switched on, it is switched on with the rules already held.
struct ShareCardBoundaryTests {

    static let artworkFile = "ShareCardArtwork.swift"

    static var lettersDirectory: URL {
        PermissionCallBoundaryTests.appTarget
            .appendingPathComponent("Features")
            .appendingPathComponent("Letters")
    }

    /// A time of day plus a named place is a statement about where a person was and when, to the
    /// minute, forwarded to strangers. The day is as fine as a card gets.
    @Test func theCardCarriesNoCoordinateNoAccuracyAndNoTimeOfDay() throws {
        let offenders = try PermissionCallBoundaryTests.occurrences(
            of: ["latitude", "longitude", "coordinate", "gpsAccuracy", "accuracyM",
                 "timeStyle", "HH:mm"],
            under: Self.lettersDirectory,
            onlyFileNamed: Self.artworkFile)
        #expect(offenders.isEmpty, "\(offenders)")
    }

    /// `AD-4`. A card is a record of a walk somebody took: it must keep saying the same thing after
    /// a content correction, after a place is withdrawn, and after the app stops shipping that
    /// quest. Reaching for a repository is how that stops being true.
    @Test func theCardRendersFromSnapshotsAndNeverFromLiveContent() throws {
        let offenders = try PermissionCallBoundaryTests.occurrences(
            of: ["ContentRepository", "repository", "BundledContentRepository"],
            under: Self.lettersDirectory,
            onlyFileNamed: Self.artworkFile)
        #expect(offenders.isEmpty, "\(offenders)")
    }

    /// And the file is where this suite thinks it is — a scan that finds nothing because somebody
    /// renamed the card is not a guard.
    @Test func theCardIsWhereThisSuiteThinksItIs() throws {
        let found = try PermissionCallBoundaryTests.occurrences(
            of: ["struct ShareCardArtwork"],
            under: Self.lettersDirectory,
            onlyFileNamed: Self.artworkFile)
        #expect(!found.isEmpty, "\(Self.artworkFile) no longer holds the recap card.")
    }
}
