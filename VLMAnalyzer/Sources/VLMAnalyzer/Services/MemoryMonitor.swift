import Darwin
import Foundation
import Observation
import SwiftUI

@Observable
@MainActor
final class MemoryMonitor {

    struct Snapshot: Identifiable {
        let id = UUID()
        let time: Date
        let usedGB: Double
        let totalGB: Double

        var usagePercent: Double { usedGB / totalGB * 100 }
        var freeRatio: Double { 1.0 - (usedGB / totalGB) }

        var pressure: Pressure {
            if freeRatio > 0.20 { return .normal }
            if freeRatio > 0.08 { return .warning }
            return .critical
        }
    }

    enum Pressure: String {
        case normal   = "正常"
        case warning  = "警告"
        case critical = "逼迫"

        var color: Color {
            switch self {
            case .normal:   return .green
            case .warning:  return .orange
            case .critical: return .red
            }
        }
    }

    var history: [Snapshot] = []
    var latest: Snapshot?

    private var timer: Timer?

    func start() {
        sample()
        let t = Timer(timeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.sample() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func sample() {
        guard let (used, total) = fetchVMStats() else { return }
        let toGB = { (b: UInt64) in Double(b) / 1_073_741_824 }
        let snap = Snapshot(time: Date(), usedGB: toGB(used), totalGB: toGB(total))
        latest = snap
        history.append(snap)
        if history.count > 90 { history.removeFirst() }
    }

    private func fetchVMStats() -> (used: UInt64, total: UInt64)? {
        let total = ProcessInfo.processInfo.physicalMemory
        var info  = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
        )
        let kr = withUnsafeMutablePointer(to: &info) { p in
            p.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { b in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, b, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return nil }
        let page = UInt64(vm_page_size)
        let used = (UInt64(info.active_count) +
                    UInt64(info.inactive_count) +
                    UInt64(info.wire_count) +
                    UInt64(info.compressor_page_count)) * page
        return (used, total)
    }
}
