import Foundation

// UUID version 7, RFC 9562 §5.7.
//
// `docs/backend-supabase.md` §2.3 pins UUIDv7 for every device-generated primary key, and `b0` D8
// records that the migrations cannot enforce it: the column is `uuid` either way and a v4 id
// inserts and works correctly. So the rule has no server-side hold, and the failure mode is silent
// — a v4 id is random across the whole 128-bit space, so every insert lands in a different B-tree
// page and the index bloats in proportion to the table. Nothing errors. Nothing is slow enough to
// notice until it is.
//
// It lives in `RunEngine` because `RunEngine` mints Run and checkpoint-result ids, and taking a
// package dependency to produce 128 bits would be the wrong trade in both directions. Foundation
// only, like the rest of this target.
//
// iOS 18 ships no native v7 generator, which is why this exists at all rather than calling one.

extension UUID {

    /// A time-ordered UUID: 48 bits of Unix milliseconds, then randomness.
    ///
    /// Two ids minted in the same millisecond sort arbitrarily against each other — RFC 9562 §6.2
    /// permits that, and the ordering that matters here is between *walks* and between *arrivals*,
    /// which are seconds and minutes apart. A within-millisecond counter would buy strict
    /// monotonicity at the cost of shared mutable state in a type that has none.
    public static func v7(now: Date = Date(), randomness: () -> UInt64 = { UInt64.random(in: 0...UInt64.max) }) -> UUID {
        let milliseconds = UInt64((now.timeIntervalSince1970 * 1000).rounded())
        let randomA = randomness()
        let randomB = randomness()

        var bytes = [UInt8](repeating: 0, count: 16)

        // Bits 0–47: big-endian Unix time in milliseconds. Big-endian is what makes the id sort in
        // time order as a byte string, which is the entire point — a little-endian timestamp would
        // be just as unique and just as bad for the index.
        bytes[0] = UInt8truncating(milliseconds >> 40)
        bytes[1] = UInt8truncating(milliseconds >> 32)
        bytes[2] = UInt8truncating(milliseconds >> 24)
        bytes[3] = UInt8truncating(milliseconds >> 16)
        bytes[4] = UInt8truncating(milliseconds >> 8)
        bytes[5] = UInt8truncating(milliseconds)

        // Bits 48–51: version 7. Bits 52–63: 12 bits of randomness.
        bytes[6] = 0x70 | UInt8truncating((randomA >> 8) & 0x0F)
        bytes[7] = UInt8truncating(randomA)

        // Bits 64–65: variant 0b10 (RFC 4122/9562). Bits 66–127: 62 bits of randomness.
        bytes[8] = 0x80 | UInt8truncating(randomB & 0x3F)
        bytes[9] = UInt8truncating(randomB >> 8)
        bytes[10] = UInt8truncating(randomB >> 16)
        bytes[11] = UInt8truncating(randomB >> 24)
        bytes[12] = UInt8truncating(randomB >> 32)
        bytes[13] = UInt8truncating(randomB >> 40)
        bytes[14] = UInt8truncating(randomA >> 16)
        bytes[15] = UInt8truncating(randomA >> 24)

        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3],
                           bytes[4], bytes[5], bytes[6], bytes[7],
                           bytes[8], bytes[9], bytes[10], bytes[11],
                           bytes[12], bytes[13], bytes[14], bytes[15]))
    }

    /// The 48-bit timestamp back out, for tests and for nothing else. Nil unless this is a v7.
    public var v7Timestamp: Date? {
        let b = uuid
        guard (b.6 & 0xF0) == 0x70 else { return nil }
        let ms = (UInt64(b.0) << 40) | (UInt64(b.1) << 32) | (UInt64(b.2) << 24)
            | (UInt64(b.3) << 16) | (UInt64(b.4) << 8) | UInt64(b.5)
        return Date(timeIntervalSince1970: Double(ms) / 1000)
    }
}

private func UInt8truncating(_ value: UInt64) -> UInt8 {
    UInt8(truncatingIfNeeded: value)
}
