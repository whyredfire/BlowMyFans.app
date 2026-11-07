import HelperInterface
import SMCKit

/// Keeps Curve mode's fan speeds steady: up at once for a real rise, down only after a lower speed
/// has been wanted for a while, and off only a few degrees into the curve's 0% region.
struct CurveSpeedHold {
    /// Smaller changes than this, in RPM, are ignored.
    static let deadband = 250.0
    /// How long a lower speed must stay wanted before the fans slow down.
    static let slowDownDelay = Duration.seconds(20)
    /// Running fans keep going at minimum until the curve is at 0% this many degrees higher too.
    static let stopMargin = 3.0

    private var rpms: [Double]?
    private var lowerSince: ContinuousClock.Instant?

    mutating func reset() {
        rpms = nil
        lowerSince = nil
    }

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

        // The slow-down wait runs for as long as the curve wants less, even when only a little less.
        if change >= 0 { lowerSince = nil }
        guard isSignificant else { return held }
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
