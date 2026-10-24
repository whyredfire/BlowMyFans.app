import Foundation
import HelperInterface

enum HelperClientError: LocalizedError {
    case unreachable
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .unreachable: String(localized: "The fan helper isn't responding.")
        case .failed(let message): message
        }
    }
}

/// Async wrapper around the XPC connection to the privileged helper.
@MainActor
final class HelperClient {
    private var connection: NSXPCConnection?

    /// Called when the helper connection drops unexpectedly (helper crashed, restarted or was
    /// replaced). The helper hands fans back to macOS when it loses a client, so any speeds
    /// applied over the old connection are gone.
    var onConnectionLost: (@MainActor () -> Void)?

    /// Returns nil when the helper isn't installed or can't be reached.
    func installedVersion() async -> String? {
        try? await call { helper, reply in
            helper.version { reply(.success($0)) }
        }
    }

    func setFanSpeeds(_ rpms: [Double]) async throws {
        try await call { helper, reply in
            helper.setFanSpeeds(rpms) { reply(Result(errorMessage: $0)) }
        }
    }

    func restoreAutomatic() async throws {
        try await call { helper, reply in
            helper.restoreAutomatic { reply(Result(errorMessage: $0)) }
        }
    }

    func disconnect() {
        connection?.invalidate()
        connection = nil
    }

    private func call<Value: Sendable>(
        _ body: (FanHelperProtocol, @escaping @Sendable (Result<Value, Error>) -> Void) -> Void
    ) async throws -> Value {
        let connection = activeConnection()
        return try await withCheckedThrowingContinuation { continuation in
            let proxy = connection.remoteObjectProxyWithErrorHandler { @Sendable error in continuation.resume(throwing: error) }
            guard let helper = proxy as? FanHelperProtocol else {
                return continuation.resume(throwing: HelperClientError.unreachable)
            }
            body(helper) { continuation.resume(with: $0) }
        }
    }

    private func activeConnection() -> NSXPCConnection {
        if let connection { return connection }

        let connection = NSXPCConnection(machServiceName: HelperIdentity.machServiceName, options: .privileged)
        connection.remoteObjectInterface = .fanHelper()
        connection.setCodeSigningRequirement(HelperIdentity.helperRequirement)

        // XPC calls these handlers on its own queue, so they must be @Sendable and hop to the main actor.
        let id = ObjectIdentifier(connection)
        connection.interruptionHandler = { @Sendable [weak self] in
            Task { @MainActor in self?.connectionLost(id, invalidated: false) }
        }
        connection.invalidationHandler = { @Sendable [weak self] in
            Task { @MainActor in self?.connectionLost(id, invalidated: true) }
        }
        connection.resume()
        self.connection = connection
        return connection
    }

    /// Ignores connections already replaced or closed via `disconnect()`.
    private func connectionLost(_ id: ObjectIdentifier, invalidated: Bool) {
        guard let current = connection, ObjectIdentifier(current) == id else { return }
        if invalidated { connection = nil }
        onConnectionLost?()
    }
}

private extension Result where Success == Void, Failure == Error {
    init(errorMessage: String?) {
        self = errorMessage.map { .failure(HelperClientError.failed($0)) } ?? .success(())
    }
}
