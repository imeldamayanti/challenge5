import Foundation
import Testing
import ContentKit
import UIStringsKit
@testable import challange_5

/// `m7` step 4 — prove the bundle is wired before filling it with 107 tests.
///
/// Debugging "the test host does not load" against one test is minutes; debugging it against the
/// whole restored suite is an afternoon. Everything this file asserts is infrastructure:
///
/// - the test bundle loads the host app (`TEST_HOST` / `BUNDLE_LOADER`),
/// - `@testable import challange_5` reaches `internal` types — the module name is `challange_5`
///   because the hyphen in the target name becomes an underscore,
/// - the package products are importable from the test target,
/// - and the content resources are actually inside the built app rather than only in the package.
@MainActor
struct HostLinkageTests {

    @Test func theHostAppsInternalTypesAreVisible() {
        #expect(!UIStringKey.allCases.isEmpty)
    }

    @Test func thePackageProductsAreLinked() throws {
        let quests = try BundledContentRepository().quests()
        #expect(!quests.isEmpty, "Content resources are missing from the built app bundle.")
    }
}
