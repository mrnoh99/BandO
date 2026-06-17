import SwiftUI
import CoreBluetooth

/// Reverse-engineering aid: pick a writable characteristic, fire candidate ANC
/// on/off encodings at it, and watch for the headphones to react. When one
/// works, mark it as the control characteristic and note which encoding worked
/// (then bake it into BeoCommand for permanent use).
struct ANCDiscoveryView: View {
    @EnvironmentObject private var bluetooth: BluetoothManager
    @ObservedObject var device: BeoDevice

    @State private var selected: CBUUID?

    /// Only writable characteristics are valid control candidates.
    private var writableCharacteristics: [(service: GATTService, char: GATTCharacteristic)] {
        device.services.flatMap { service in
            service.characteristics
                .filter { $0.canWrite }
                .map { (service, $0) }
        }
    }

    private var selectedNode: GATTCharacteristic? {
        guard let selected else { return nil }
        return device.services
            .flatMap { $0.characteristics }
            .first { $0.uuid == selected }
    }

    var body: some View {
        List {
            Section {
                Text("Send candidate ANC commands to a characteristic and listen for the headphones to react. When one works, tap “Set as control” and tell me the working encoding — I'll bake the real opcode into the app.")
                    .font(.callout)
            }

            Section("1. Choose a target characteristic") {
                if writableCharacteristics.isEmpty {
                    Label("No writable characteristics were discovered over BLE. ANC on this unit is likely controlled over Bluetooth Classic, which iOS can't reach without MFi.",
                          systemImage: "exclamationmark.triangle")
                        .font(.callout)
                        .foregroundStyle(.orange)
                }
                ForEach(writableCharacteristics, id: \.char.id) { item in
                    Button {
                        selected = item.char.uuid
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.char.name).font(.subheadline)
                                Text("in \(item.service.name)")
                                    .font(.caption2).foregroundStyle(.secondary)
                                Text(item.char.uuid.uuidString)
                                    .font(.caption2.monospaced()).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if selected == item.char.uuid {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.beoAccent)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            if let node = selectedNode {
                Section("2. Fire candidate encodings") {
                    ForEach(BeoCommand.ancCandidates(on: true)) { candidate in
                        CandidateRow(label: candidate.label,
                                     onData: candidate.data,
                                     offData: matchingOff(for: candidate.label),
                                     node: node, device: device)
                    }
                }

                Section {
                    Button {
                        bluetooth.setControlCharacteristic(node, on: device)
                    } label: {
                        Label(device.controlCharacteristicUUID == node.uuid
                              ? "This is the control characteristic"
                              : "Set as control characteristic",
                              systemImage: "slider.horizontal.3")
                    }
                    .disabled(device.controlCharacteristicUUID == node.uuid)

                    if node.canNotify {
                        Button {
                            bluetooth.setNotify(!node.isNotifying, for: node, on: device)
                        } label: {
                            Label(node.isNotifying ? "Stop watching responses" : "Watch responses (subscribe)",
                                  systemImage: "dot.radiowaves.left.and.right")
                        }
                    }
                } footer: {
                    if let status = device.controlStatus {
                        Text(status).font(.caption)
                    }
                }
            }
        }
        .navigationTitle("ANC Discovery")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { selected = device.controlCharacteristicUUID ?? selected }
    }

    /// Pair each ON candidate with its OFF counterpart by index.
    private func matchingOff(for label: String) -> Data {
        let ons = BeoCommand.ancCandidates(on: true)
        let offs = BeoCommand.ancCandidates(on: false)
        if let idx = ons.firstIndex(where: { $0.label == label }) {
            return offs[idx].data
        }
        return offs.first?.data ?? Data()
    }
}

private struct CandidateRow: View {
    @EnvironmentObject private var bluetooth: BluetoothManager
    let label: String
    let onData: Data
    let offData: Data
    let node: GATTCharacteristic
    @ObservedObject var device: BeoDevice

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.subheadline)
            HStack(spacing: 10) {
                Button {
                    bluetooth.write(onData, to: node, on: device)
                    device.controlStatus = "Tried ON \(onData.hexString) → \(node.name)"
                } label: {
                    Text("ON  \(onData.hexString)")
                        .font(.caption.monospaced())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button {
                    bluetooth.write(offData, to: node, on: device)
                    device.controlStatus = "Tried OFF \(offData.hexString) → \(node.name)"
                } label: {
                    Text("OFF \(offData.hexString)")
                        .font(.caption.monospaced())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 2)
    }
}
