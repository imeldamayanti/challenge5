import Foundation
import Testing
@testable import RunEngine

/// RFC 9562 §5.7, `docs/backend-supabase.md` §2.3, `b0` D8.
///
/// The server cannot hold this rule — a v4 id inserts and works — so the whole guarantee rests on
/// these assertions. The failure it prevents is silent: v4 ids are random across the full 128-bit
/// space, so every insert lands in a different B-tree page and the index bloats in proportion to
/// the table, with nothing erroring and nothing slow enough to notice until it is.
struct UUIDv7Tests {

    @Test func theVersionNibbleIsSeven() {
        for _ in 0..<200 {
            let id = UUID.v7()
            #expect((id.uuid.6 & 0xF0) == 0x70, "\(id) is not version 7")
        }
    }

    @Test func theVariantIsRFC9562() {
        for _ in 0..<200 {
            // Two most significant bits of octet 8 are 0b10.
            #expect((UUID.v7().uuid.8 & 0xC0) == 0x80)
        }
    }

    @Test func theFirstFortyEightBitsAreTheTimestamp() throws {
        let when = Date(timeIntervalSince1970: 1_786_000_000)
        let id = UUID.v7(now: when)
        let recovered = try #require(id.v7Timestamp)
        #expect(abs(recovered.timeIntervalSince(when)) < 0.002)
    }

    /// The property the whole change exists for: ids minted later sort after ids minted earlier,
    /// as byte strings. Anything else is a v4 with extra steps.
    @Test func idsMintedLaterSortAfterIdsMintedEarlier() {
        let base = Date(timeIntervalSince1970: 1_786_000_000)
        var previous = UUID.v7(now: base)
        for step in 1...100 {
            let next = UUID.v7(now: base.addingTimeInterval(Double(step) * 0.05))
            #expect(bytes(previous).lexicographicallyPrecedes(bytes(next)),
                    "\(previous) did not sort before \(next)")
            previous = next
        }
    }

    /// A generator that is time-ordered and not unique is worse than one that is neither. The
    /// randomness is what stops two devices arriving at the same millisecond from colliding.
    @Test func idsMintedInTheSameMillisecondAreStillDistinct() {
        let when = Date(timeIntervalSince1970: 1_786_000_000)
        let ids = Set((0..<2_000).map { _ in UUID.v7(now: when) })
        #expect(ids.count == 2_000)
    }

    /// The v4 `UUID()` this replaces is *not* a v7, and `v7Timestamp` must say so rather than
    /// reading four random bytes as a date.
    @Test func aVersionFourIdIsNotMistakenForATimestamp() {
        #expect(UUID().v7Timestamp == nil)
    }

    private func bytes(_ id: UUID) -> [UInt8] {
        let u = id.uuid
        return [u.0, u.1, u.2, u.3, u.4, u.5, u.6, u.7,
                u.8, u.9, u.10, u.11, u.12, u.13, u.14, u.15]
    }
}
