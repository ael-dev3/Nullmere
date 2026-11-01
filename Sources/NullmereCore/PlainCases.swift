/// A kind written by its name, compared and hashed by which case it is.
/// Swift would otherwise compare such a kind letter by letter by its name,
/// and hash every letter of it, at every comparison and at every look into
/// a table it keys, as a hold's works are kept: in a wide realm's watch
/// that is hundreds of thousands of times. Two kinds are the same just
/// when their names are, so every answer is the one the names give.
public protocol PlainCases: RawRepresentable, Hashable where RawValue == String {}

extension PlainCases {
    @inlinable public static func == (lhs: Self, rhs: Self) -> Bool { lhs.caseNumber == rhs.caseNumber }

    @inlinable public func hash(into hasher: inout Hasher) { hasher.combine(caseNumber) }

    /// Which case it is: a kind of plain cases, from two to 256 of them, is
    /// held in a byte numbering its case.
    @inlinable var caseNumber: UInt8 { unsafeBitCast(self, to: UInt8.self) }
}
