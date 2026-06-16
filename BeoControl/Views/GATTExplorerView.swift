import SwiftUI

/// Live view of the full GATT tree with read / write / subscribe — the surface
/// for actually reaching B&O's proprietary characteristics once identified.
struct GATTExplorerView: View {
    @EnvironmentObject private var bluetooth: BluetoothManager
    @ObservedObject var device: BeoDevice

    var body: some View {
        List {
            if device.services.isEmpty {
                ContentUnavailableView("No services discovered",
                                       systemImage: "antenna.radiowaves.left.and.right",
                                       description: Text("Connect to the device to discover its GATT tree."))
            }
            ForEach(device.services) { service in
                Section {
                    ForEach(service.characteristics) { characteristic in
                        CharacteristicRow(device: device, characteristic: characteristic)
                    }
                } header: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(service.name)
                        Text(service.uuid.uuidString)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("GATT Explorer")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct CharacteristicRow: View {
    @EnvironmentObject private var bluetooth: BluetoothManager
    @ObservedObject var device: BeoDevice
    let characteristic: GATTCharacteristic

    @State private var writeHex = ""
    @State private var showWrite = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(characteristic.name).font(.subheadline.bold())
            Text(characteristic.uuid.uuidString)
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                Text(characteristic.propertyDescription)
                    .font(.caption2)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.15), in: Capsule())
                if characteristic.isNotifying {
                    Text("LIVE").font(.caption2.bold()).foregroundStyle(.green)
                }
                if device.controlCharacteristicUUID == characteristic.uuid {
                    Label("CONTROL", systemImage: "slider.horizontal.3")
                        .font(.caption2.bold()).foregroundStyle(.beoAccent)
                }
            }

            if let value = characteristic.lastValue {
                VStack(alignment: .leading, spacing: 2) {
                    Text(value.hexString)
                        .font(.caption.monospaced())
                    if let text = String(data: value, encoding: .utf8),
                       text.allSatisfy({ $0.isASCII && !$0.isNewline }) , !text.isEmpty {
                        Text("“\(text)”").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }

            HStack(spacing: 16) {
                if characteristic.canRead {
                    Button {
                        bluetooth.read(characteristic, on: device)
                    } label: { Label("Read", systemImage: "arrow.down.circle") }
                }
                if characteristic.canNotify {
                    Button {
                        bluetooth.setNotify(!characteristic.isNotifying, for: characteristic, on: device)
                    } label: {
                        Label(characteristic.isNotifying ? "Unsubscribe" : "Subscribe",
                              systemImage: "dot.radiowaves.left.and.right")
                    }
                }
                if characteristic.canWrite {
                    Button {
                        showWrite.toggle()
                    } label: { Label("Write", systemImage: "arrow.up.circle") }
                    Button {
                        bluetooth.setControlCharacteristic(characteristic, on: device)
                    } label: {
                        Label(device.controlCharacteristicUUID == characteristic.uuid
                              ? "Control" : "Use for control",
                              systemImage: "slider.horizontal.3")
                    }
                    .disabled(device.controlCharacteristicUUID == characteristic.uuid)
                }
            }
            .font(.caption)
            .buttonStyle(.borderless)

            if showWrite {
                HStack {
                    TextField("Hex e.g. 01 A0 FF", text: $writeHex)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                        .font(.caption.monospaced())
                    Button("Send") {
                        if let data = Data(hexString: writeHex) {
                            bluetooth.write(data, to: characteristic, on: device)
                            writeHex = ""
                            showWrite = false
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(Data(hexString: writeHex) == nil)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
