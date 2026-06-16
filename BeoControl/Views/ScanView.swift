import SwiftUI
import CoreBluetooth

struct ScanView: View {
    @EnvironmentObject private var bluetooth: BluetoothManager

    var body: some View {
        NavigationStack {
            List {
                if bluetooth.state != .poweredOn {
                    Section {
                        BluetoothStatusBanner(state: bluetooth.state)
                    }
                }

                Section {
                    ForEach(bluetooth.devices) { device in
                        NavigationLink {
                            DeviceDetailView(device: device)
                        } label: {
                            DeviceRow(device: device)
                        }
                    }
                } header: {
                    HStack {
                        Text("Nearby Devices")
                        Spacer()
                        if bluetooth.isScanning {
                            ProgressView().controlSize(.small)
                        }
                    }
                } footer: {
                    if bluetooth.devices.isEmpty {
                        Text(bluetooth.onlyShowBeo
                             ? "Searching for Bang & Olufsen headphones. Make sure your H95 or Portal is powered on and in range."
                             : "Searching for all Bluetooth LE peripherals.")
                    }
                }

                Section {
                    Toggle("Only show Bang & Olufsen", isOn: $bluetooth.onlyShowBeo)
                }
            }
            .navigationTitle("BandO")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        bluetooth.isScanning ? bluetooth.stopScan() : bluetooth.startScan()
                    } label: {
                        Label(bluetooth.isScanning ? "Stop" : "Scan",
                              systemImage: bluetooth.isScanning ? "stop.circle" : "arrow.clockwise")
                    }
                    .disabled(bluetooth.state != .poweredOn)
                }
            }
        }
    }
}

struct DeviceRow: View {
    @ObservedObject var device: BeoDevice

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: device.product.systemImage)
                .font(.title2)
                .frame(width: 40, height: 40)
                .background(Color.beoAccent.opacity(0.15), in: Circle())
                .foregroundStyle(Color.beoAccent)

            VStack(alignment: .leading, spacing: 2) {
                Text(device.displayName).font(.headline)
                Text(device.product == .unknown ? device.advertisedName : device.product.tagline)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if let battery = device.batteryLevel {
                    BatteryBadge(level: battery)
                }
                SignalStrength(rssi: device.rssi)
            }
        }
        .padding(.vertical, 4)
    }
}

struct BluetoothStatusBanner: View {
    let state: CBManagerState

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            VStack(alignment: .leading, spacing: 2) {
                Text("Bluetooth is \(state.description)").font(.subheadline.bold())
                Text(message).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    var message: String {
        switch state {
        case .poweredOff: return "Turn on Bluetooth in Control Center or Settings."
        case .unauthorized: return "Allow Bluetooth access for BandO in Settings › Privacy."
        case .unsupported: return "This device does not support Bluetooth LE."
        default: return "Waiting for Bluetooth to become available…"
        }
    }
}
