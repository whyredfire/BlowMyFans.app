import Foundation
import IOKit
import Synchronization

public enum SMCError: LocalizedError {
    /// SMC result code for a key this machine doesn't have.
    static let keyNotFound: UInt8 = 0x84

    case serviceUnavailable
    case invalidKey(String)
    case kernel(kern_return_t)
    case smc(key: String, code: UInt8)
    case sizeMismatch(key: String, expected: Int, actual: Int)
    case unsupportedType(key: String, type: String)

    public var errorDescription: String? {
        switch self {
        case .serviceUnavailable: "AppleSMC service not found"
        case .invalidKey(let key): "Invalid SMC key '\(key)'"
        case .kernel(let code): "IOKit error 0x\(String(UInt32(bitPattern: code), radix: 16))"
        case .smc(let key, Self.keyNotFound): "SMC key '\(key)' not found"
        case .smc(let key, let code): "SMC error 0x\(String(code, radix: 16)) for key '\(key)'"
        case .sizeMismatch(let key, let expected, let actual): "SMC key '\(key)' expects \(expected) bytes, got \(actual)"
        case .unsupportedType(let key, let type): "SMC key '\(key)' has unsupported type '\(type)'"
        }
    }
}

public struct SMCKeyInfo: Sendable {
    public let size: Int
    public let type: String
}

/// Connection to the AppleSMC user client. Reads work unprivileged; writes require root.
public final class SMC: Sendable {
    private let connection: io_connect_t
    /// Key attributes by key code; `nil` entries record keys this machine doesn't have.
    private let infoCache = Mutex<[UInt32: SMCKeyInfo?]>([:])

    public init() throws {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { throw SMCError.serviceUnavailable }
        defer { IOObjectRelease(service) }

        var connection: io_connect_t = 0
        let result = IOServiceOpen(service, mach_task_self_, 0, &connection)
        guard result == KERN_SUCCESS else { throw SMCError.kernel(result) }
        self.connection = connection
    }

    deinit {
        IOServiceClose(connection)
    }

    public func info(_ key: String) throws -> SMCKeyInfo {
        let code = try fourCharCode(key)
        if let cached = infoCache.withLock({ $0[code] }) {
            guard let cached else { throw SMCError.smc(key: key, code: SMCError.keyNotFound) }
            return cached
        }
        do {
            let output = try call(SMCParamBlock(key: code, command: .keyInfo), key: key)
            let info = SMCKeyInfo(size: Int(output.dataSize), type: output.dataType.fourCharString)
            infoCache.withLock { $0[code] = info }
            return info
        } catch SMCError.smc(_, SMCError.keyNotFound) {
            infoCache.withLock { $0[code] = .some(nil) }
            throw SMCError.smc(key: key, code: SMCError.keyNotFound)
        }
    }

    public func contains(_ key: String) -> Bool {
        (try? info(key)) != nil
    }

    public func read(_ key: String) throws -> SMCValue {
        let info = try info(key)
        var input = SMCParamBlock(key: try fourCharCode(key), command: .readBytes)
        input.dataSize = UInt32(info.size)
        let output = try call(input, key: key)
        return SMCValue(type: info.type, bytes: output.payload(count: info.size))
    }

    public func readDouble(_ key: String) -> Double? {
        try? read(key).doubleValue
    }

    public func write(_ key: String, bytes: [UInt8]) throws {
        let info = try info(key)
        guard bytes.count == info.size else {
            throw SMCError.sizeMismatch(key: key, expected: info.size, actual: bytes.count)
        }
        var input = SMCParamBlock(key: try fourCharCode(key), command: .writeBytes)
        input.dataSize = UInt32(info.size)
        input.setPayload(bytes)
        _ = try call(input, key: key)
    }

    /// Encodes `value` using the key's native SMC type before writing.
    public func write(_ key: String, value: Double) throws {
        let info = try info(key)
        guard let bytes = SMCValue.encode(value, type: info.type, size: info.size) else {
            throw SMCError.unsupportedType(key: key, type: info.type)
        }
        try write(key, bytes: bytes)
    }

    public func allKeys() throws -> [String] {
        let count = try read("#KEY").bytes.reduce(0) { $0 << 8 | Int($1) }
        return (0..<count).compactMap { index in
            var input = SMCParamBlock(key: 0, command: .keyAtIndex)
            input.index = UInt32(index)
            return try? call(input, key: "#\(index)").key.fourCharString
        }
    }

    private func call(_ input: SMCParamBlock, key: String) throws -> SMCParamBlock {
        var output = SMCParamBlock()
        var outputSize = SMCParamBlock.size
        let result = input.bytes.withUnsafeBytes { inputBuffer in
            output.bytes.withUnsafeMutableBytes { outputBuffer in
                IOConnectCallStructMethod(
                    connection, 2,
                    inputBuffer.baseAddress, SMCParamBlock.size,
                    outputBuffer.baseAddress, &outputSize
                )
            }
        }
        guard result == KERN_SUCCESS else { throw SMCError.kernel(result) }
        guard output.result == 0 else { throw SMCError.smc(key: key, code: output.result) }
        return output
    }

    private func fourCharCode(_ key: String) throws -> UInt32 {
        guard let code = UInt32(fourCharCode: key) else { throw SMCError.invalidKey(key) }
        return code
    }
}
