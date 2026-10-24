import Foundation
import IOKit
import IOKit.pwr_mgt

/// Delivers system sleep and wake notifications from IOKit's root power domain.
///
/// The `kIOMessage*` constants are function-like macros that Swift can't import, so their
/// values (`iokit_common_msg(n)` = 0xE0000000 | n) are spelled out here.
final class PowerMonitor: @unchecked Sendable {
    private enum Message {
        static let canSystemSleep: UInt32 = 0xE000_0270
        static let systemWillSleep: UInt32 = 0xE000_0280
        static let systemHasPoweredOn: UInt32 = 0xE000_0300
    }

    private let willSleep: @Sendable () -> Void
    private let didWake: @Sendable () -> Void
    // Written once in `start`, then only read from the notification queue.
    private var rootPort: io_connect_t = 0
    private var notificationPort: IONotificationPortRef?
    private var notifier: io_object_t = 0

    /// `willSleep` must finish its work synchronously; sleep proceeds once it returns.
    init(willSleep: @escaping @Sendable () -> Void, didWake: @escaping @Sendable () -> Void) {
        self.willSleep = willSleep
        self.didWake = didWake
    }

    /// Starts delivering notifications on `queue`. The monitor must stay alive for the process lifetime.
    func start(on queue: DispatchQueue) {
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        rootPort = IORegisterForSystemPower(refcon, &notificationPort, powerCallback, &notifier)
        guard rootPort != 0, let notificationPort else {
            NSLog("Unable to register for system power notifications")
            return
        }
        IONotificationPortSetDispatchQueue(notificationPort, queue)
    }

    fileprivate func handle(_ messageType: UInt32, argument: UnsafeMutableRawPointer?) {
        switch messageType {
        case Message.canSystemSleep:
            // Idle sleep may still be vetoed by someone else, so keep control until it's certain.
            IOAllowPowerChange(rootPort, Int(bitPattern: argument))
        case Message.systemWillSleep:
            willSleep()
            IOAllowPowerChange(rootPort, Int(bitPattern: argument))
        case Message.systemHasPoweredOn:
            didWake()
        default:
            break
        }
    }
}

/// C callback for `IORegisterForSystemPower`; nonisolated by construction.
private func powerCallback(
    refcon: UnsafeMutableRawPointer?, service: io_service_t, messageType: UInt32, argument: UnsafeMutableRawPointer?
) {
    guard let refcon else { return }
    Unmanaged<PowerMonitor>.fromOpaque(refcon).takeUnretainedValue().handle(messageType, argument: argument)
}
