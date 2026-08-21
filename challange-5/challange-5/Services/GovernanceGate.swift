import Foundation
import GovernanceKit
import Observation

/// The app's view of the kill-switch (`AD-5`, `FR-ERR-09`, `NFR-SEC-02`, `c2` phase 0).
///
/// `GovernanceKit` already owns the fetching, the schema validation and the last-good copy. This is
/// the thing the SwiftUI layer can read: an `@Observable` holder whose sets are available
/// **synchronously, from disk, before any fetch is attempted**. That ordering is the requirement —
/// launch does not wait on the network, and the fetch *updates* an answer rather than producing
/// one.
///
/// **There is no reachability check here and there must never be one** (`AD-3`). A refresh is
/// attempted; it succeeds or it does not, and every way it can fail keeps what the app already had.
/// Nothing on screen learns that a refresh happened.
@MainActor
@Observable
final class GovernanceGate {

    /// What the app should currently be hiding. Never nil: with no document ever fetched this is
    /// `.empty`, which suppresses nothing.
    private(set) var document: SuppressionsDocument

    /// Nil when the build carries no backend configuration. The gate then holds whatever the last
    /// good copy on disk says, forever, and the app behaves exactly as it does today.
    private let service: GovernanceService?

    init(
        configuration: BackendConfiguration?,
        store: any GovernanceStore = FileGovernanceStore(
            directory: GovernanceGate.defaultDirectory()),
        transport: any GovernanceTransport = URLSessionGovernanceTransport()
    ) {
        // Synchronous, from the same store the service will use. Reading it through the actor would
        // make the first draw of the quest list wait on an actor hop for a value already on disk.
        document = store.loadLastGood() ?? .empty
        service = configuration.map {
            GovernanceService(url: $0.suppressionsURL, transport: transport, store: store)
        }
    }

    /// One opportunistic refresh. Returns nothing and throws nothing: there is exactly one correct
    /// behaviour on failure, which is to keep the current document.
    func refresh() async {
        guard let service else { return }
        document = await service.refresh()
    }

    var suppressedPlaceIDs: Set<String> { Set(document.suppressedPlaceIDs) }
    var suppressedQuestIDs: Set<String> { Set(document.suppressedQuestIDs) }
    var suppressedSideQuestIDs: Set<String> { Set(document.suppressedSideQuestIDs) }

    /// Whether a walk in progress has had its ground cut out from under it (`AD-5`,
    /// `AbandonReason.placeSuppressed`).
    ///
    /// A **finished** walk is never affected and this is not asked about one: its lore, place names
    /// and citations were copied into the Run at completion, the walk happened, and suppression must
    /// not reach into a summary.
    func suppresses(questID: String, placeIDs: [String]) -> Bool {
        if suppressedQuestIDs.contains(questID) { return true }
        let places = suppressedPlaceIDs
        return placeIDs.contains { places.contains($0) }
    }

    /// Beside the Run store and the sidequest store, under the same `Kultara/` root.
    static func defaultDirectory() -> URL {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent("Kultara/backend", isDirectory: true)
    }
}
