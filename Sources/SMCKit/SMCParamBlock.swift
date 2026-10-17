/// The 80-byte struct exchanged with the AppleSMC user client (selector 2).
struct SMCParamBlock {
    enum Command: UInt8 {
        case readBytes = 5
        case writeBytes = 6
        case keyAtIndex = 8
        case keyInfo = 9
    }

    static let size = 80
    private static let payloadOffset = 48

    var bytes = [UInt8](repeating: 0, count: size)

    init() {}

    init(key: UInt32, command: Command) {
        self.key = key
        bytes[42] = command.rawValue
    }

    var key: UInt32 {
        get { load(at: 0) }
        set { store(newValue, at: 0) }
    }

    var dataSize: UInt32 {
        get { load(at: 28) }
        set { store(newValue, at: 28) }
    }

    var dataType: UInt32 { load(at: 32) }

    var result: UInt8 { bytes[40] }

    var index: UInt32 {
        get { load(at: 44) }
        set { store(newValue, at: 44) }
    }

    func payload(count: Int) -> [UInt8] {
        Array(bytes[Self.payloadOffset..<Self.payloadOffset + count])
    }

    mutating func setPayload(_ payload: [UInt8]) {
        bytes.replaceSubrange(Self.payloadOffset..<Self.payloadOffset + payload.count, with: payload)
    }

    private func load(at offset: Int) -> UInt32 {
        bytes.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: UInt32.self) }
    }

    private mutating func store(_ value: UInt32, at offset: Int) {
        bytes.withUnsafeMutableBytes { $0.storeBytes(of: value, toByteOffset: offset, as: UInt32.self) }
    }
}

extension UInt32 {
    init?(fourCharCode string: String) {
        let ascii = Array(string.utf8)
        guard ascii.count == 4 else { return nil }
        self = ascii.reduce(0) { $0 << 8 | UInt32($1) }
    }

    var fourCharString: String {
        String(decoding: [24, 16, 8, 0].map { UInt8(truncatingIfNeeded: self >> $0) }, as: UTF8.self)
    }
}
