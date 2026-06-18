import SwiftUI

/// Active noise-control selector. Writes the encoded command to hardware via
/// the mapped control characteristic, and updates device state.
struct ANCControl: View {
    @EnvironmentObject private var bluetooth: BluetoothManager
    @ObservedObject var device: BeoDevice

    private var ancOn: Binding<Bool> {
        Binding(
            get: { device.control.ancMode != .off },
            set: { _ in bluetooth.toggleANC(on: device) }
        )
    }

    private var mode: Binding<ANCMode> {
        Binding(
            get: { device.control.ancMode },
            set: { bluetooth.setANCMode($0, on: device) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle(isOn: ancOn) {
                Label("Noise cancellation", systemImage: "wave.3.right.circle.fill")
                    .font(.headline)
            }

            Picker("Mode", selection: mode) {
                ForEach(ANCMode.allCases) { m in
                    Label(m.rawValue, systemImage: m.systemImage).tag(m)
                }
            }
            .pickerStyle(.segmented)

            Text(device.control.ancMode.detail)
                .font(.caption)
                .foregroundStyle(.secondary)

            if device.controlCharacteristicUUID == nil {
                Label("Mapped to state only — set a control characteristic in GATT Explorer or ANC Discovery to send to hardware.",
                      systemImage: "exclamationmark.triangle")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }

            if let status = device.controlStatus {
                Text(status)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }

            if device.control.ancMode == .transparency || device.control.ancMode == .adaptive {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "wave.3.right")
                        Slider(
                            value: Binding(
                                get: { device.control.transparencyLevel },
                                set: { device.control.transparencyLevel = $0 } ),
                            in: 0...1,
                            onEditingChanged: { editing in
                                if !editing {
                                    bluetooth.setTransparency(device.control.transparencyLevel, on: device)
                                }
                            }
                        )
                        Image(systemName: "ear")
                    }
                    Text("ANC ←→ Transparency: \(Int(device.control.transparencyLevel * 100))%")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct SoundControl: View {
    @ObservedObject var device: BeoDevice

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Label("Volume", systemImage: "speaker.wave.3")
                    .font(.subheadline)
                HStack {
                    Image(systemName: "speaker")
                    Slider(value: $device.control.volume)
                    Image(systemName: "speaker.wave.3")
                }
            }

            Picker("Tone preset", selection: $device.control.eqPreset) {
                ForEach(EQPreset.allCases) { Text($0.rawValue).tag($0) }
            }

            ToneSlider(title: "Bass", systemImage: "dial.low",
                       value: $device.control.bassBoost)
            ToneSlider(title: "Treble", systemImage: "dial.high",
                       value: $device.control.trebleBoost)
        }
        .padding(.vertical, 4)
    }
}

struct ToneSlider: View {
    let title: String
    let systemImage: String
    @Binding var value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Label(title, systemImage: systemImage).font(.subheadline)
                Spacer()
                Text(String(format: "%+.0f", value * 10))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(value: $value, in: -1...1)
        }
    }
}

struct XboxControl: View {
    @ObservedObject var device: BeoDevice

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle(isOn: $device.control.xboxWirelessEnabled) {
                Label("Xbox Wireless", systemImage: "gamecontroller.fill")
            }

            Toggle(isOn: $device.control.dolbyAtmosEnabled) {
                Label("Dolby Atmos for Headphones", systemImage: "airpodsmax")
            }

            Picker("Microphone", selection: $device.control.micMode) {
                ForEach(MicMode.allCases) { Text($0.rawValue).tag($0) }
            }

            VStack(alignment: .leading, spacing: 4) {
                Label("Game / Chat balance", systemImage: "person.2.wave.2")
                    .font(.subheadline)
                HStack {
                    Image(systemName: "gamecontroller")
                    Slider(value: $device.control.gameChatBalance)
                    Image(systemName: "message")
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Label("Sidetone (own voice)", systemImage: "mic")
                    .font(.subheadline)
                Slider(value: $device.control.sidetoneLevel)
            }
        }
        .padding(.vertical, 4)
    }
}
