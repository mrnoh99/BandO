import SwiftUI

struct DeviceDetailView: View {
    @EnvironmentObject private var bluetooth: BluetoothManager
    @ObservedObject var device: BeoDevice

    var isReady: Bool { device.connectionState == .ready }

    var body: some View {
        List {
            Section { DeviceHeader(device: device) }

            Section("Connection") {
                ConnectionRow(device: device)
            }

            if isReady {
                Section("Battery & Info") {
                    if let battery = device.batteryLevel {
                        LabeledContent("Battery") { BatteryBadge(level: battery) }
                    }
                    infoRow("Manufacturer", device.manufacturer)
                    infoRow("Model", device.modelNumber)
                    infoRow("Firmware", device.firmwareRevision)
                    infoRow("Serial", device.serialNumber)
                }

                Section {
                    ANCControl(device: device)
                    NavigationLink {
                        ANCDiscoveryView(device: device)
                    } label: {
                        Label("ANC Discovery", systemImage: "scope")
                    }
                } header: {
                    Text("Noise Control")
                } footer: {
                    ProprietaryNote()
                }

                Section("Sound") {
                    SoundControl(device: device)
                }

                if device.product.supportsXbox {
                    Section {
                        XboxControl(device: device)
                    } header: {
                        Label("Xbox & Gaming", systemImage: "gamecontroller.fill")
                    }
                }

                Section {
                    NavigationLink {
                        GATTExplorerView(device: device)
                    } label: {
                        Label("GATT Explorer", systemImage: "antenna.radiowaves.left.and.right")
                    }
                } footer: {
                    Text("Inspect every service and characteristic, read/write raw values, and subscribe to notifications — the path to driving real proprietary control.")
                }
            }
        }
        .navigationTitle(device.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func infoRow(_ label: String, _ value: String?) -> some View {
        if let value, !value.isEmpty {
            LabeledContent(label, value: value)
        }
    }
}

struct DeviceHeader: View {
    @ObservedObject var device: BeoDevice

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: device.product.systemImage)
                .font(.system(size: 34))
                .frame(width: 64, height: 64)
                .background(Color.beoAccent.opacity(0.15), in: RoundedRectangle(cornerRadius: 16))
                .foregroundStyle(Color.beoAccent)
            VStack(alignment: .leading, spacing: 4) {
                Text(device.displayName).font(.title2.bold())
                Text(device.product.tagline).font(.subheadline).foregroundStyle(.secondary)
                SignalStrength(rssi: device.rssi)
            }
            Spacer()
        }
        .padding(.vertical, 6)
    }
}

struct ConnectionRow: View {
    @EnvironmentObject private var bluetooth: BluetoothManager
    @ObservedObject var device: BeoDevice

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
            Spacer()
            switch device.connectionState {
            case .connecting, .discovering:
                ProgressView().controlSize(.small)
            case .ready, .connected:
                Button("Disconnect", role: .destructive) { bluetooth.disconnect(device) }
                    .buttonStyle(.bordered)
            default:
                Button("Connect") { bluetooth.connect(device) }
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    var label: String {
        switch device.connectionState {
        case .disconnected: return "Not connected"
        case .connecting: return "Connecting…"
        case .connected: return "Connected"
        case .discovering: return "Discovering services…"
        case .ready: return "Connected & ready"
        case .failed: return "Connection failed"
        }
    }

    var color: Color {
        switch device.connectionState {
        case .ready, .connected: return .green
        case .connecting, .discovering: return .yellow
        case .failed: return .red
        case .disconnected: return .gray
        }
    }
}

struct ProprietaryNote: View {
    var body: some View {
        Text("Battery and device info are read live over standard Bluetooth LE. ANC, EQ and gaming controls drive B&O's proprietary protocol — wire the reverse-engineered characteristic UUID into BeoGATT and the GATT Explorer to deliver them to hardware.")
            .font(.caption2)
    }
}
