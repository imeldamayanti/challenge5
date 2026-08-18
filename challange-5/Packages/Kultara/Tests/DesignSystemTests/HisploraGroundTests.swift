import Testing
@testable import DesignSystem

/// The printed ground `547:2953` exports.
struct HisploraGroundTests {

    @Test func thePrintedGroundShips() {
        // Same guard as `PaperTextureTests`: dropping the resource from `Package.swift` should turn
        // this red rather than quietly flattening the Journal and the Explorer's Card.
        #expect(HisploraGround.isAvailable)
    }
}
