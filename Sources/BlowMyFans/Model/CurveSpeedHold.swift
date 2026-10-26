import HelperInterface
import SMCKit

/// Keeps Curve mode's fan speeds steady through the small temperature swings of normal use.
///
/// Speeds go up as soon as the curve asks for noticeably more, but come down only once the lower
/// speed has been wanted for a while, so bursty work doesn't send the fans up and down. Running fans
/// stop only once the chip is a few degrees into the curve's 0% region, not the moment it gets there.
struct CurveSpeedHold {
    /// Smaller changes than this, in RPM, are ignored.
    static let deadband = 250.0
    /// How long a lower speed must stay wanted before the fans slow down.
    static let slowDownDelay = Duration.seconds(20)
    /// Running fans keep going at minimum until the curve is at 0% this many degrees higher too.
    static let stopMargin = 3.0

    /// The speeds being held, as last returned.
    private(set) var rpms: [Double]?
    private var lowerSince: ContinuousClock.Instant?

    mutating func reset() {
        rpms = nil
        lowerSince = nil
    }

    /// The speeds to apply, given what the curve asks for at `temperature`.
    mutating func speeds(
        for target: [Double], fans: [Fan], curve: FanCurve, temperature: Double?, now: ContinuousClock.Instant
    ) -> [Double] {
        guard let held = rpms, held.count == target.count, fans.count == target.count else {
            return hold(target)
        }

        var wanted = target
        let isRunning = held.contains { $0 != FanSpeedRequest.off }
        if isRunning, target.allSatisfy({ $0 == FanSpeedRequest.off }),
           let temperature, curve.speed(at: temperature + Self.stopMargin) > 0 {
            wanted = fans.map(\.minimumRPM)
        }

        // Fans move together on a curve, so the largest change decides. Off counts as 0 RPM.
        let rpm = { (value: Double) in value == FanSpeedRequest.off ? 0 : value }
        let change = zip(wanted, held).map { rpm($0) - rpm($1) }.max { abs($0) < abs($1) } ?? 0
        let reachesLimit = zip(wanted, fans).contains { wanted, fan in
            change > 0 ? wanted >= fan.maximumRPM : wanted == FanSpeedRequest.off || wanted <= fan.minimumRPM
        }
        let isSignificant = abs(change) >= Self.deadband || (change != 0 && reachesLimit)

        guard isSignificant else {
            lowerSince = nil
            return held
        }
        if change > 0 {
            return hold(wanted)
        }
        let since = lowerSince ?? now
        lowerSince = since
        return now - since >= Self.slowDownDelay ? hold(wanted) : held
    }

    private mutating func hold(_ speeds: [Double]) -> [Double] {
        rpms = speeds
        lowerSince = nil
        return speeds
    }
}
