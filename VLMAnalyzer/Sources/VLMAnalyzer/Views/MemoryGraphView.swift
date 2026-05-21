import Charts
import SwiftUI

struct MemoryGraphView: View {
    let monitor: MemoryMonitor

    private var totalGB: Double { monitor.latest?.totalGB ?? 36 }

    var body: some View {
        HStack(spacing: 14) {
            statsLabel
            Divider().frame(height: 36)
            chart
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Stats label

    private var statsLabel: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let snap = monitor.latest {
                HStack(spacing: 5) {
                    Circle()
                        .fill(snap.pressure.color)
                        .frame(width: 7, height: 7)
                    Text("メモリ圧: \(snap.pressure.rawValue)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Text(String(format: "%.1f / %.0f GB  (%.0f%%)",
                            snap.usedGB, snap.totalGB, snap.usagePercent))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            } else {
                Text("メモリ取得中…")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(width: 168, alignment: .leading)
    }

    // MARK: - Chart

    private var chart: some View {
        Chart {
            ForEach(monitor.history) { snap in
                AreaMark(
                    x: .value("Time", snap.time),
                    y: .value("GB", snap.usedGB)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [chartColor.opacity(0.45), chartColor.opacity(0.08)],
                        startPoint: .top, endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("Time", snap.time),
                    y: .value("GB", snap.usedGB)
                )
                .foregroundStyle(chartColor)
                .lineStyle(StrokeStyle(lineWidth: 1.5))
            }

            // 80% reference line
            RuleMark(y: .value("80%", totalGB * 0.8))
                .foregroundStyle(.orange.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .annotation(position: .trailing) {
                    Text("80%")
                        .font(.system(size: 8))
                        .foregroundStyle(.orange.opacity(0.7))
                }
        }
        .chartXAxis(.hidden)
        .chartYScale(domain: 0...totalGB)
        .chartYAxis {
            AxisMarks(values: [0, totalGB * 0.5, totalGB]) { val in
                AxisGridLine().foregroundStyle(.secondary.opacity(0.25))
                AxisValueLabel {
                    if let v = val.as(Double.self) {
                        Text(v == 0 ? "0" : "\(Int(v))G")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(width: 240, height: 46)
    }

    private var chartColor: Color {
        switch monitor.latest?.pressure {
        case .warning:  return .orange
        case .critical: return .red
        default:        return .blue
        }
    }
}
