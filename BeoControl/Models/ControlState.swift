import Foundation

/// Active noise-control mode shared by H95 and Portal.
enum ANCMode: String, CaseIterable, Identifiable {
    case off = "Off"
    case on = "Active"
    case transparency = "Transparency"
    case adaptive = "Adaptive"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .off: return "speaker.wave.1"
        case .on: return "wave.3.right.circle.fill"
        case .transparency: return "ear"
        case .adaptive: return "sparkles"
        }
    }

    var detail: String {
        switch self {
        case .off: return "No active noise control"
        case .on: return "Block out surrounding noise"
        case .transparency: return "Let ambient sound in"
        case .adaptive: return "Auto-adjust to surroundings"
        }
    }
}

/// Five-band tone preset offered by the B&O app's "Beosonic" / EQ surface.
enum EQPreset: String, CaseIterable, Identifiable {
    case neutral = "Neutral"
    case bright = "Bright"
    case warm = "Warm"
    case energetic = "Energetic"
    case relaxed = "Relaxed"
    case commute = "Commute"

    var id: String { rawValue }
}

/// Portal-only microphone routing.
enum MicMode: String, CaseIterable, Identifiable {
    case auto = "Auto"
    case boom = "Boom Arm"
    case beamforming = "Virtual Boom"
    case muted = "Muted"

    var id: String { rawValue }
}

/// The control surface state for a device. Values that map to standard GATT
/// are kept in sync with real reads; proprietary ones reflect intent.
struct ControlState {
    var ancMode: ANCMode = .adaptive
    var transparencyLevel: Double = 0.5     // 0 = full ANC ... 1 = full transparency
    var volume: Double = 0.6                // 0...1
    var eqPreset: EQPreset = .neutral
    var bassBoost: Double = 0.0             // -1...1
    var trebleBoost: Double = 0.0           // -1...1

    // Portal / Xbox-specific
    var xboxWirelessEnabled: Bool = false
    var micMode: MicMode = .auto
    var sidetoneLevel: Double = 0.3         // hear your own voice
    var gameChatBalance: Double = 0.5       // 0 = game ... 1 = chat
    var dolbyAtmosEnabled: Bool = true
}
