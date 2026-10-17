import Foundation

/// Temperature sensors published through IOKit's private HID event system (Apple silicon only).
final class HIDTemperatureSensors: @unchecked Sendable {
    private static let temperatureEvent: Int64 = 15
    private static let temperatureField = Int32(15 << 16)

    private let api: API?
    private let client: CFTypeRef?
    private let services: [(name: String, service: AnyObject)]

    init() {
        guard let api = API.load(), let client = api.createClient(kCFAllocatorDefault)?.takeRetainedValue() else {
            (api, client, services) = (nil, nil, [])
            return
        }
        _ = api.setMatching(client, ["PrimaryUsagePage": 0xff00, "PrimaryUsage": 0x0005] as CFDictionary)
        let all = (api.copyServices(client)?.takeRetainedValue() as? [AnyObject]) ?? []
        self.api = api
        self.client = client
        services = all.compactMap { service in
            (api.copyProperty(service, "Product" as CFString)?.takeRetainedValue() as? String).map { ($0, service) }
        }
    }

    var names: Set<String> { Set(services.map(\.name)) }

    /// Highest reading per sensor name; several services can share one name.
    func read(_ names: Set<String>) -> [String: Double] {
        guard let api, !names.isEmpty else { return [:] }
        var values: [String: Double] = [:]
        for (name, service) in services where names.contains(name) {
            guard let event = api.copyEvent(service, Self.temperatureEvent, 0, 0)?.takeRetainedValue() else { continue }
            values[name] = max(values[name] ?? -.infinity, api.floatValue(event, Self.temperatureField))
        }
        return values
    }

    private struct API {
        typealias CreateClient = @convention(c) (CFAllocator?) -> Unmanaged<CFTypeRef>?
        typealias SetMatching = @convention(c) (CFTypeRef, CFDictionary) -> Int32
        typealias CopyServices = @convention(c) (CFTypeRef) -> Unmanaged<CFArray>?
        typealias CopyProperty = @convention(c) (CFTypeRef, CFString) -> Unmanaged<CFTypeRef>?
        typealias CopyEvent = @convention(c) (CFTypeRef, Int64, Int32, Int64) -> Unmanaged<CFTypeRef>?
        typealias FloatValue = @convention(c) (CFTypeRef, Int32) -> Double

        let createClient: CreateClient
        let setMatching: SetMatching
        let copyServices: CopyServices
        let copyProperty: CopyProperty
        let copyEvent: CopyEvent
        let floatValue: FloatValue

        static func load() -> API? {
            guard let handle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_NOW) else { return nil }
            func symbol<T>(_ name: String, as type: T.Type) -> T? {
                dlsym(handle, name).map { unsafeBitCast($0, to: type) }
            }
            guard let createClient = symbol("IOHIDEventSystemClientCreate", as: CreateClient.self),
                  let setMatching = symbol("IOHIDEventSystemClientSetMatching", as: SetMatching.self),
                  let copyServices = symbol("IOHIDEventSystemClientCopyServices", as: CopyServices.self),
                  let copyProperty = symbol("IOHIDServiceClientCopyProperty", as: CopyProperty.self),
                  let copyEvent = symbol("IOHIDServiceClientCopyEvent", as: CopyEvent.self),
                  let floatValue = symbol("IOHIDEventGetFloatValue", as: FloatValue.self)
            else { return nil }
            return API(createClient: createClient, setMatching: setMatching, copyServices: copyServices,
                       copyProperty: copyProperty, copyEvent: copyEvent, floatValue: floatValue)
        }
    }
}
