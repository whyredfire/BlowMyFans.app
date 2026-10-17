/// Raw bytes of an SMC key plus its 4-char data type (e.g. `flt `, `ui8 `, `sp78`).
public struct SMCValue: Sendable, Equatable {
    public let type: String
    public let bytes: [UInt8]

    public var doubleValue: Double? {
        switch type {
        case "flt " where bytes.count == 4:
            Double(Float(bitPattern: littleEndianInteger))
        case "sp78" where bytes.count == 2:
            Double(Int16(bitPattern: UInt16(bigEndianInteger))) / 256
        case "ui8 ", "ui16", "ui32":
            Double(bigEndianInteger)
        default:
            nil
        }
    }

    static func encode(_ value: Double, type: String, size: Int) -> [UInt8]? {
        switch (type, size) {
        case ("flt ", 4):
            withUnsafeBytes(of: Float(value).bitPattern.littleEndian, Array.init)
        case ("ui8 ", 1), ("ui16", 2), ("ui32", 4):
            (0..<size).reversed().map { UInt8(truncatingIfNeeded: UInt64(max(0, value)) >> ($0 * 8)) }
        default:
            nil
        }
    }

    private var bigEndianInteger: UInt32 {
        bytes.prefix(4).reduce(0) { $0 << 8 | UInt32($1) }
    }

    private var littleEndianInteger: UInt32 {
        bytes.prefix(4).reversed().reduce(0) { $0 << 8 | UInt32($1) }
    }
}
