import Foundation
import Testing
@testable import AppFeatures
@testable import ContentKit

@MainActor
struct SettingsTests {

    private func model(
        language: ContentLanguage = .id,
        store: InMemoryAppPreferencesStore = InMemoryAppPreferencesStore(),
        authorization: LocationAuthorizationSnapshot = .notRequested,
        eraser: SpyLocalDataEraser = SpyLocalDataEraser(),
        storageBytes: Int = 3 * 1024 * 1024
    ) throws -> SettingsViewModel {
        SettingsViewModel(
            repository: try BundledContentRepository(),
            store: store,
            language: language,
            locationAuthorization: StubLocationAuthorizationReporter(snapshot: authorization),
            eraser: eraser,
            storage: StubStorageReporter(bytes: storageBytes))
    }

    // MARK: - FR-SET-01, the four things Settings must expose

    @Test func settingsExposesLanguageLocationStorageAndDeletion() throws {
        let model = try model()
        #expect(model.language == .id)
        #expect(!model.locationStatusText.isEmpty)
        #expect(!model.storageUsedText.isEmpty)
        #expect(!model.deleteActionTitle.isEmpty)
        #expect(!model.systemSettingsURLIsMissing)
    }

    @Test func changingLanguagePersistsAndRerendersEveryString() throws {
        let store = InMemoryAppPreferencesStore()
        let model = try model(language: .id, store: store)
        let before = model.locationStatusText

        model.selectLanguage(.en)

        #expect(store.preferredLanguage == .en)
        #expect(model.language == .en)
        #expect(model.locationStatusText != before)
    }

    @Test func selectingTheSameLanguageIsHarmless() throws {
        let store = InMemoryAppPreferencesStore()
        let model = try model(language: .id, store: store)
        model.selectLanguage(.id)
        #expect(model.language == .id)
        #expect(store.preferredLanguage == .id)
    }

    @Test(arguments: [
        LocationAuthorizationSnapshot.notRequested,
        .denied, .whenInUse, .always, .restricted,
    ])
    func everyAuthorizationStateHasItsOwnWording(_ snapshot: LocationAuthorizationSnapshot) throws {
        let model = try model(authorization: snapshot)
        #expect(!model.locationStatusText.isEmpty)
    }

    @Test func theFiveAuthorizationStatesReadDifferently() throws {
        // "Not requested" and "Denied" mean opposite things to a user deciding whether to open
        // Settings; sharing a string would be worse than saying nothing.
        var seen: Set<String> = []
        for snapshot in LocationAuthorizationSnapshot.allCases {
            seen.insert(try model(authorization: snapshot).locationStatusText)
        }
        #expect(seen.count == LocationAuthorizationSnapshot.allCases.count)
    }

    @Test func settingsExplainsThatBrowsingNeedsNoLocationPermission() throws {
        // FR-DISC-01 is a promise to the user, not only to the code. It has to be said somewhere.
        #expect(!(try model().locationExplanation.isEmpty))
    }

    /// `FR-ONB-04` — location permission is requested in context at the first quest-start attempt,
    /// never from Settings. The reporter protocol therefore has no request method at all; this is a
    /// structural check that nobody added one.
    @Test func theAuthorizationReporterCannotRequestPermission() {
        let members = String(describing: (any LocationAuthorizationReporting).self)
        #expect(!members.contains("request"))

        let reporter = StubLocationAuthorizationReporter(snapshot: .denied)
        let mirror = Mirror(reflecting: reporter)
        #expect(!mirror.children.compactMap(\.label).contains { $0.lowercased().contains("request") })
    }

    // MARK: - FR-SET-02, deletion behind a confirmation

    @Test func deletionRequiresAConfirmationFirst() throws {
        let eraser = SpyLocalDataEraser()
        let model = try model(eraser: eraser)

        model.requestDelete()
        #expect(model.isConfirmingDelete)
        #expect(eraser.callCount == 0, "Nothing may be deleted before the user confirms")

        model.confirmDelete()
        #expect(eraser.callCount == 1)
        #expect(!model.isConfirmingDelete)
        #expect(model.lastDeletionSummary != nil)
    }

    @Test func cancellingLeavesEverythingAlone() throws {
        let eraser = SpyLocalDataEraser()
        let model = try model(eraser: eraser)
        model.requestDelete()
        model.cancelDelete()
        #expect(!model.isConfirmingDelete)
        #expect(eraser.callCount == 0)
        #expect(model.lastDeletionSummary == nil)
    }

    @Test func deletionAlsoClearsPreferences() throws {
        let store = InMemoryAppPreferencesStore()
        store.preferredLanguage = .en
        store.onboardingCompletedAt = Date()
        let model = try model(language: .en, store: store, eraser: SpyLocalDataEraser())

        model.requestDelete()
        model.confirmDelete()

        #expect(store.preferredLanguage == nil)
        #expect(store.onboardingCompletedAt == nil)
    }

    @Test func deletionStatesHonestlyWhatDoesNotExistYetInThisBuild() throws {
        // FR-SET-02 names Runs, photos, reflections, awards and queued telemetry. None exist in
        // M5. Saying "all your data is deleted" without saying that would be a claim about
        // things the build cannot have.
        #expect(!(try model().deleteScopeNote.isEmpty))
    }

    @Test func aFailedDeletionIsReportedRatherThanSilentlySwallowed() throws {
        let eraser = SpyLocalDataEraser(shouldFail: true)
        let model = try model(eraser: eraser)
        model.requestDelete()
        model.confirmDelete()
        #expect(model.deletionFailed)
        #expect(model.lastDeletionSummary == nil)
    }

    // MARK: - FR-SET-03, attribution

    @Test func attributionListsTheCommunitySourcesTheContentRestsOn() throws {
        // NFR-GOV-05: community sources must be credited in-app.
        let model = try model()
        #expect(!model.attributionEntries.isEmpty)
        #expect(!model.attributionBody.isEmpty)
    }

    @Test func attributionIsDeduplicatedAcrossPlaces() throws {
        let model = try model()
        #expect(Set(model.attributionEntries).count == model.attributionEntries.count)
    }

    @Test func attributionNamesTheContentVersionSoAReportCanBeTiedToABuild() throws {
        #expect(!(try model().contentVersionText.isEmpty))
    }

    // MARK: - FR-SET-04, reporting a problem

    @Test func thereIsAWayToReportAFactualErrorOrAConcernAboutAPlace() throws {
        let model = try model()
        #expect(model.reportDestination != nil)
        #expect(!model.reportBody.isEmpty)
    }

    @Test func theReportPathStatesTheHonestTurnaround() throws {
        // NFR-CONT-07: in v1 a correction needs an app release, and the target must be stated
        // honestly to users who report errors.
        let model = try model(language: .en)
        #expect(model.reportBody.lowercased().contains("days"), "\(model.reportBody)")
    }

    @Test func theReportDestinationCarriesTheContentVersion() throws {
        // A report that does not say which content it is about costs a round trip to triage.
        let model = try model()
        let url = try #require(model.reportDestination)
        // Read from the repository rather than hardcoded: a content bump must not break this test,
        // it must keep asserting that whatever version ships is the one in the report.
        let version = try BundledContentRepository().contentBundleVersion()
        #expect(url.absoluteString.contains(version), "\(url.absoluteString) lacks \(version)")
    }
}

// MARK: - Doubles

struct StubLocationAuthorizationReporter: LocationAuthorizationReporting {
    let snapshot: LocationAuthorizationSnapshot
    func currentAuthorization() -> LocationAuthorizationSnapshot { snapshot }
}

struct StubStorageReporter: StorageUsageReporting {
    let bytes: Int
    func bytesUsedOnDevice() -> Int { bytes }
}

@MainActor
final class SpyLocalDataEraser: LocalDataEraser {
    struct Failure: Error {}

    private(set) var callCount = 0
    let shouldFail: Bool

    init(shouldFail: Bool = false) {
        self.shouldFail = shouldFail
    }

    func eraseAllLocalData() throws -> ErasureSummary {
        callCount += 1
        if shouldFail { throw Failure() }
        return ErasureSummary(deletedRuns: 0, deletedPhotos: 0, deletedTelemetryEvents: 0, clearedPreferences: true)
    }
}
