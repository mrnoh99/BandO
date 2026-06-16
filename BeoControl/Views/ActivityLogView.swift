import SwiftUI

struct ActivityLogView: View {
    @EnvironmentObject private var bluetooth: BluetoothManager

    var body: some View {
        NavigationStack {
            List {
                if bluetooth.log.isEmpty {
                    ContentUnavailableView("No activity yet",
                                           systemImage: "list.bullet.rectangle",
                                           description: Text("Bluetooth events and GATT traffic appear here."))
                }
                ForEach(bluetooth.log) { entry in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: entry.level.symbol)
                            .foregroundStyle(entry.level.color)
                            .font(.caption)
                            .frame(width: 18)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.message).font(.callout)
                            Text(entry.date, style: .time)
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Activity")
        }
    }
}

extension BluetoothManager.LogEntry.Level {
    var symbol: String {
        switch self {
        case .info: return "info.circle"
        case .success: return "checkmark.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.octagon"
        case .traffic: return "arrow.left.arrow.right"
        }
    }
    var color: Color {
        switch self {
        case .info: return .secondary
        case .success: return .green
        case .warning: return .orange
        case .error: return .red
        case .traffic: return .beoAccent
        }
    }
}
