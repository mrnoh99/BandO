import SwiftUI

/// Active noise-control selector. Updates device state and (when a control
/// characteristic has been mapped) writes the encoded command to hardware.
struct ANCControl: View {
    @ObservedObject var device: BeoDevice

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("Mode", selection: Binding(
                get: { device.control.ancMode },
                set: { device.control.ancMode = $0 }
            )) {
                ForEach(ANCMode.allCases) { mode in
                    Label(mode.rawValue, systemImage: mode.systemImage).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Text(device.control.ancMode.detail)
                .font(.caption)
                .foregroundStyle(.secondary)

            if device.control.ancMode == .transparency || device.control.ancMode == .adaptive {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "wave.3.right")
                        Slider(value: $device.control.transparencyLevel)
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
