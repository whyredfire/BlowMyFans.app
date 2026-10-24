import Charts
import SwiftUI

/// Editable fan curve: CPU temperature on x, share of the fan range on y.
/// Drag points to adjust, double-click empty space to add a point, double-click a point to remove it.
struct FanCurveEditor: View {
    @Environment(FanController.self) private var controller
    @Environment(HardwareMonitor.self) private var monitor
    @Environment(AppSettings.self) private var settings

    /// Point being dragged; `.some(nil)` when the drag started away from any point.
    @GestureState private var dragTarget: CurvePoint.ID?? = nil

    private let height: CGFloat = 150
    private let hitRadius: CGFloat = 14
    private var curve: FanCurve { controller.draft.curve }
    private var domain: ClosedRange<Double> { FanCurve.temperatureRange }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            chart
                .frame(height: height)
            footer
        }
    }

    private var chart: some View {
        Chart {
            ForEach(samples, id: \.temperature) { point in
                AreaMark(x: .value("Temperature", point.temperature), y: .value("Speed", point.speed * 100))
                    .foregroundStyle(.linearGradient(colors: [Color.accentColor.opacity(0.28), Color.accentColor.opacity(0.02)],
                                                     startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("Temperature", point.temperature), y: .value("Speed", point.speed * 100))
                    .foregroundStyle(Color.accentColor)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            }
            if let temperature = currentTemperature {
                RuleMark(x: .value("Now", temperature))
                    .foregroundStyle(.secondary.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
            }
            ForEach(curve.points) { point in
                PointMark(x: .value("Temperature", point.temperature), y: .value("Speed", point.speed * 100))
                    .symbol {
                        let size: CGFloat = dragTarget == .some(point.id) ? 16 : 11
                        Circle()
                            .fill(.white)
                            .stroke(Color.accentColor, lineWidth: 2.5)
                            .frame(width: size, height: size)
                            .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                    }
            }
            if let temperature = currentTemperature {
                PointMark(x: .value("Now", temperature), y: .value("Speed", curve.speed(at: temperature) * 100))
                    .symbol {
                        Circle()
                            .fill(.orange)
                            .frame(width: 9, height: 9)
                            .shadow(color: .orange.opacity(0.7), radius: 4)
                    }
            }
        }
        .chartXScale(domain: domain)
        .chartYScale(domain: 0...100)
        .chartXAxis {
            AxisMarks(values: .stride(by: 20)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(.quaternary)
                AxisValueLabel {
                    if let celsius = value.as(Double.self) { Text(settings.format(celsius)) }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: [0, 50, 100]) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(.quaternary)
                AxisValueLabel {
                    if let percent = value.as(Int.self) { Text("\(percent)%") }
                }
            }
        }
        .help("Drag points to adjust · double-click to add or remove")
        .chartOverlay { proxy in
            GeometryReader { geometry in
                if let plotFrame = proxy.plotFrame {
                    let origin = geometry[plotFrame].origin
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .gesture(dragGesture(proxy: proxy, origin: origin))
                        .onTapGesture(count: 2) { location in
                            toggle(at: location, proxy: proxy, origin: origin)
                        }
                }
            }
        }
    }

    @ViewBuilder
    private var footer: some View {
        if let temperature = currentTemperature {
            Text("CPU \(settings.format(temperature)) → \(speedText(curve.speed(at: temperature)))")
                .monospacedDigit()
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Data

    private var currentTemperature: Double? {
        controller.curveTemperature.map { min(max($0, domain.lowerBound), domain.upperBound) }
    }

    /// The curve sampled across the chart, so the drawn line matches the applied speeds exactly.
    private var samples: [(temperature: Double, speed: Double)] {
        stride(from: domain.lowerBound, through: domain.upperBound, by: 0.5).map { ($0, curve.speed(at: $0)) }
    }

    private func speedText(_ fraction: Double) -> String {
        if settings.allowFanOff, fraction == 0 { return "Off" }
        guard let range = monitor.fanSpeedRange else { return "\(Int(fraction * 100))%" }
        let rpm = range.lowerBound + fraction * (range.upperBound - range.lowerBound)
        return "\(Int(fraction * 100))% (\(rpm.rpmText))"
    }

    // MARK: Interaction

    private func dragGesture(proxy: ChartProxy, origin: CGPoint) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .updating($dragTarget) { value, target, _ in
                if target == nil {
                    target = .some(nearestPoint(to: value.startLocation, proxy: proxy, origin: origin))
                }
                guard let id = target ?? nil, let (temperature, speed) = values(at: value.location, proxy: proxy, origin: origin) else { return }
                controller.draft.curve.move(id, temperature: temperature, speed: speed)
            }
    }

    private func toggle(at location: CGPoint, proxy: ChartProxy, origin: CGPoint) {
        if let id = nearestPoint(to: location, proxy: proxy, origin: origin) {
            controller.draft.curve.remove(id)
        } else if let (temperature, speed) = values(at: location, proxy: proxy, origin: origin) {
            controller.draft.curve.add(temperature: temperature, speed: speed)
        }
    }

    private func values(at location: CGPoint, proxy: ChartProxy, origin: CGPoint) -> (Double, Double)? {
        guard let temperature = proxy.value(atX: location.x - origin.x, as: Double.self),
              let percent = proxy.value(atY: location.y - origin.y, as: Double.self) else { return nil }
        return (temperature, percent / 100)
    }

    private func nearestPoint(to location: CGPoint, proxy: ChartProxy, origin: CGPoint) -> CurvePoint.ID? {
        curve.points
            .compactMap { point -> (CurvePoint.ID, CGFloat)? in
                guard let x = proxy.position(forX: point.temperature),
                      let y = proxy.position(forY: point.speed * 100) else { return nil }
                return (point.id, hypot(x + origin.x - location.x, y + origin.y - location.y))
            }
            .filter { $0.1 <= hitRadius }
            .min { $0.1 < $1.1 }?
            .0
    }
}
