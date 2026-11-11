import Foundation
import Security

public enum HelperIdentity {
    public static let appBundleID = "dev.whyredfire.blowmyfans"
    public static let label = "dev.whyredfire.blowmyfans.helper"
    public static let machServiceName = label

    /// Bump whenever the helper changes so the app knows to reinstall it.
    public static let version = "11"

    /// What the helper requires of a connecting app, and the app of the helper.
    ///
    /// Signed with a Developer ID, each side also requires the other to come from its own team, which
    /// nothing else can claim. An ad-hoc signature has no team, so only the identifier is checked, and
    /// any local program can sign itself with that; the helper limits what such a caller can do to the
    /// fans (see `FanSession`), but can't tell it from the app.
    public static let clientRequirement = requirement(identifier: appBundleID)
    public static let helperRequirement = requirement(identifier: label)

    private static func requirement(identifier: String) -> String {
        let identity = #"identifier "\#(identifier)""#
        guard let team = teamIdentifier else { return identity }
        return identity + #" and anchor apple generic and certificate leaf[subject.OU] = "\#(team)""#
    }

    /// The team that signed the running program, or nil for an ad-hoc or self-signed one.
    private static let teamIdentifier: String? = {
        var code: SecCode?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code else { return nil }
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode else { return nil }
        var information: CFDictionary?
        let flags = SecCSFlags(rawValue: kSecCSSigningInformation)
        guard SecCodeCopySigningInformation(staticCode, flags, &information) == errSecSuccess,
              let team = (information as? [String: Any])?[kSecCodeInfoTeamIdentifier as String] as? String,
              // It goes into a requirement string, so accept nothing that could change its meaning.
              !team.isEmpty, team.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }) else { return nil }
        return team
    }()
}

public enum FanSpeedRequest {
    /// The only value that stops a fan; anything else is clamped to the fan's range.
    public static let off: Double = -1
    /// Clamped to each fan's maximum.
    public static let full = Double.greatestFiniteMagnitude
}

/// What the helper is doing for a client, as `keepAlive` reports it.
public enum FanHelperState: Int, Sendable {
    /// The helper holds no speeds for this client; macOS runs the fans.
    case released
    /// The requested speeds are in force.
    case applied
    /// The Mac is too hot, so the fans run at full speed instead until it has cooled down.
    case cooling
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

    /// Tells the helper the client that set the speeds is still running; without it the helper hands
    /// the fans back to macOS. Replies with a `FanHelperState` raw value.
    func keepAlive(reply: @escaping @Sendable (Int) -> Void)
}

extension NSXPCInterface {
    public static func fanHelper() -> NSXPCInterface {
        let interface = NSXPCInterface(with: FanHelperProtocol.self)
        let speedClasses = NSSet(array: [NSArray.self, NSNumber.self]) as! Set<AnyHashable>
        interface.setClasses(speedClasses, for: #selector(FanHelperProtocol.setFanSpeeds(_:reply:)), argumentIndex: 0, ofReply: false)
        return interface
    }
}
