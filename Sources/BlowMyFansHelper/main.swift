import Foundation
import HelperInterface
import SMCKit

// Top-level code is main-actor isolated, so closures run on other queues are marked
// `@Sendable` to stop them inheriting that isolation (which would trap at runtime).

// Fan writes can block for seconds while the SMC hands over control, so the watchdog runs on
// its own serial queue and the main queue stays free for SIGTERM and power notifications.
let controlQueue = DispatchQueue(label: "\(HelperIdentity.label).control")

// The system can silently take fans back (e.g. after wake); the watchdog re-applies the requested
// speed. It only runs while the session has something to maintain, so an idle helper never wakes.
let watchdog = DispatchSource.makeTimerSource(queue: controlQueue)

let session: FanSession
do {
    session = FanSession(writer: FanWriter(smc: try SMC())) { @Sendable [watchdog] needed in
        if needed {
            watchdog.schedule(deadline: .now() + 3, repeating: 3, leeway: .milliseconds(500))
        } else {
            watchdog.schedule(deadline: .distantFuture, repeating: .never)
        }
    }
} catch {
    NSLog("Unable to open SMC: %@", error.localizedDescription)
    exit(EXIT_FAILURE)
}
watchdog.setEventHandler { @Sendable [session] in session.maintain() }
watchdog.activate()
session.releaseStaleControl()

let delegate = ListenerDelegate(session: session)
let listener = NSXPCListener(machServiceName: HelperIdentity.machServiceName)
listener.setConnectionCodeSigningRequirement(HelperIdentity.clientRequirement)
listener.delegate = delegate
listener.resume()

let powerMonitor = PowerMonitor(
    willSleep: { @Sendable [session] in session.systemWillSleep() },
    didWake: { @Sendable [session, controlQueue] in
        session.systemDidWake()
        controlQueue.async { @Sendable in session.maintain() }
    }
)
powerMonitor.start(on: .main)

// launchd sends SIGTERM on uninstall and shutdown.
signal(SIGTERM, SIG_IGN)
let termination = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
termination.setEventHandler { @Sendable [session] in
    session.prepareForExit()
    exit(EXIT_SUCCESS)
}
termination.resume()

dispatchMain()
