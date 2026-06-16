import SwiftUI

extension Color {
    /// Bang & Olufsen-ish warm brass accent.
    static let beoAccent = Color(red: 0.78, green: 0.62, blue: 0.38)
}

struct BatteryBadge: View {
    let level: Int   // 0...100

    var body: some View {
        Label("\(level)%", systemImage: symbol)
            .font(.caption.bold())
            .foregroundStyle(color)
            .labelStyle(.titleAndIcon)
    }

    private var symbol: String {
        switch level {
        case ..<13: return "battery.0percent"
        case ..<38: return "battery.25percent"
        case ..<63: return "battery.50percent"
        case ..<88: return "battery.75percent"
        default: return "battery.100percent"
        }
    }

    private var color: Color {
        switch level {
        case ..<15: return .red
        case ..<30: return .orange
        default: return .green
        }
    }
}

struct SignalStrength: View {
    let rssi: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "dot.radiowaves.left.and.right")
            Text("\(rssi) dBm")
        }
        .font(.caption2)
        .foregroundStyle(color)
    }

    private var color: Color {
        switch rssi {
        case (-60)...: return .green
        case (-75)..<(-60): return .yellow
        default: return .secondary
        }
    }
}
