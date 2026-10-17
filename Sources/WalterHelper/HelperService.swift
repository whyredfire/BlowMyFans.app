import Foundation
import HelperInterface

/// Per-connection object exported to the app.
final class HelperService: NSObject, FanHelperProtocol, Sendable {
    private let session: FanSession
    private let client: FanSession.ClientID

    init(session: FanSession, client: FanSession.ClientID) {
        self.session = session
        self.client = client
    }

    func version(reply: @escaping @Sendable (String) -> Void) {
        reply(HelperIdentity.version)
    }

    func setFanSpeeds(_ rpms: [Double], reply: @escaping @Sendable (String?) -> Void) {
        reply(perform { try session.setSpeeds(rpms, for: client) })
    }

    func restoreAutomatic(reply: @escaping @Sendable (String?) -> Void) {
        reply(perform { try session.restoreAutomatic() })
    }

    private func perform(_ body: () throws -> Void) -> String? {
        do {
            try body()
            return nil
        } catch {
            NSLog("Fan command failed: %@", error.localizedDescription)
            return error.localizedDescription
        }
    }
}

final class ListenerDelegate: NSObject, NSXPCListenerDelegate, Sendable {
    private let session: FanSession

    init(session: FanSession) {
        self.session = session
    }

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        let client = ObjectIdentifier(connection)
        connection.exportedInterface = .fanHelper()
        connection.exportedObject = HelperService(session: session, client: client)
        connection.invalidationHandler = { [session] in session.clientDisconnected(client) }
        connection.resume()
        return true
    }
}
