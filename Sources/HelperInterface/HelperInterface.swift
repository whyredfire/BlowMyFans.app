import Foundation

public enum HelperIdentity {
    public static let appBundleID = "dev.whyredfire.walter"
    public static let label = "dev.whyredfire.walter.helper"
    public static let machServiceName = label

    /// Bump whenever the helper changes so the app knows to reinstall it.
    public static let version = "9"

    public static let clientRequirement = #"identifier "\#(appBundleID)""#
    public static let helperRequirement = #"identifier "\#(label)""#
}

public enum FanSpeedRequest {
    /// The only value that stops a fan; anything else is clamped to the fan's range.
    public static let off: Double = -1
}

/// Fan commands exposed by the privileged helper. Replies carry an error message, or nil on success.
@objc(FanHelperProtocol)
public protocol FanHelperProtocol {
    func version(reply: @escaping @Sendable (String) -> Void)

    /// Puts every fan in manual mode, one speed per fan in hardware order. Fails without
    /// touching the fans if a fan's range can't be read. If macOS hasn't released the fans
    /// yet, it still succeeds and the helper keeps trying until it does.
    func setFanSpeeds(_ rpms: [Double], reply: @escaping @Sendable (String?) -> Void)

    func restoreAutomatic(reply: @escaping @Sendable (String?) -> Void)
}

extension NSXPCInterface {
    public static func fanHelper() -> NSXPCInterface {
        let interface = NSXPCInterface(with: FanHelperProtocol.self)
        let speedClasses = NSSet(array: [NSArray.self, NSNumber.self]) as! Set<AnyHashable>
        interface.setClasses(speedClasses, for: #selector(FanHelperProtocol.setFanSpeeds(_:reply:)), argumentIndex: 0, ofReply: false)
        return interface
    }
}
