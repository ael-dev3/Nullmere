/// Whole numbers that are mostly small, as runs of ground and the lie of
/// the land travel: seven bits to a byte, the lowest first, every byte but
/// a number's last with its top bit set.
enum Varint {
    static func append(_ value: Int, to bytes: inout [UInt8]) {
        precondition(value >= 0, "A count is never below none")
        append(UInt64(value), to: &bytes)
    }

    static func append(_ value: UInt64, to bytes: inout [UInt8]) {
        var rest = value
        while rest >= 0x80 {
            bytes.append(UInt8(rest & 0x7F) | 0x80)
            rest >>= 7
        }
        bytes.append(UInt8(rest))
    }

    /// A difference either way as a number not below none: 0, -1, 1, -2, 2
    /// as 0, 1, 2, 3, 4, so a small one is a small number whichever way.
    static func zigzag(_ value: Int) -> UInt64 {
        UInt64(bitPattern: Int64((value << 1) ^ (value >> (Int.bitWidth - 1))))
    }

    /// The difference `zigzag` made a number of.
    static func unzigzag(_ value: UInt64) -> Int {
        Int(Int64(bitPattern: (value >> 1) ^ (0 &- (value & 1))))
    }

    /// Bytes read from the first, a number or a byte at a time.
    struct Reader {
        private let bytes: [UInt8]
        private var at = 0

        init(_ bytes: [UInt8]) {
            self.bytes = bytes
        }

        /// Whether every byte has been read.
        var isAtEnd: Bool { at == bytes.count }

        /// The next number; nil if the bytes end within it, or it is wider
        /// than sixty-four bits.
        mutating func next() -> UInt64? {
            var value: UInt64 = 0
            var shift: UInt64 = 0
            while at < bytes.count {
                let byte = bytes[at]
                at += 1
                // The tenth byte holds the sixty-fourth bit alone.
                guard shift < 63 || byte <= 1 else { return nil }
                value |= UInt64(byte & 0x7F) << shift
                if byte & 0x80 == 0 { return value }
                shift += 7
            }
            return nil
        }

        /// The next number as a count; nil if there is none, or it is more
        /// than any count.
        mutating func count() -> Int? {
            next().flatMap { Int(exactly: $0) }
        }

        /// The next byte as it is.
        mutating func byte() -> UInt8? {
            guard at < bytes.count else { return nil }
            defer { at += 1 }
            return bytes[at]
        }
    }
}
