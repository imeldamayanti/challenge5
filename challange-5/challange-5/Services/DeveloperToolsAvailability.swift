import Foundation

#if KULTARA_DEV_TOOLS
/// Decides whether the developer tools — the arrival bypass in particular — may be reached in this
/// build, at runtime.
///
/// The compile-time flag `KULTARA_DEV_TOOLS` is set on Debug *and* Release for the app target, so
/// the switch survives an archive and reaches a TestFlight tester who cannot stand in Denpasar.
/// That alone would also put it in an App Store build, which `FR-START-08`'s release acceptance
/// criterion 13 does not allow — so this second, runtime gate closes it: a build installed from the
/// App Store carries a production receipt and answers `false`, and the Settings section, the
/// provider switch and the stored preference all read as absent there.
///
/// The receipt's file name is the documented way to tell the two apart: TestFlight installs write
/// `sandboxReceipt`, an App Store install writes `receipt`. A simulator or a build with no receipt
/// at all is a development install, which is the case Debug already covers.
enum DeveloperToolsAvailability {

    /// `true` in a Debug build, and in a TestFlight (sandbox-receipt) build. `false` in an App
    /// Store build.
    static let isEnabled: Bool = {
        #if DEBUG
        return true
        #else
        return isTestFlightInstall
        #endif
    }()

    static var isTestFlightInstall: Bool {
        guard let receiptURL = Bundle.main.appStoreReceiptURL else { return false }
        return receiptURL.lastPathComponent == "sandboxReceipt"
    }
}
#endif
