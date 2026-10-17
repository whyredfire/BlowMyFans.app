import Foundation

extension UserDefaults {
    func decoded<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        data(forKey: key).flatMap { try? JSONDecoder().decode(type, from: $0) }
    }

    func setEncoded(_ value: some Encodable, forKey key: String) {
        set(try? JSONEncoder().encode(value), forKey: key)
    }
}

extension KeyedDecodingContainer {
    /// The decoded value, or `defaultValue` if it's missing or malformed.
    func value<T: Decodable>(for key: Key, default defaultValue: T) -> T {
        (try? decodeIfPresent(T.self, forKey: key)) ?? defaultValue
    }
}
