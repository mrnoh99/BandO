import Foundation

/// Encodes high-level control intents into the byte frames sent to a B&O
/// control characteristic.
///
/// ⚠️ Bang & Olufsen's control protocol is proprietary and undocumented. The
/// opcodes below are a clearly-marked, structured *placeholder* frame so the
/// write path is real and end-to-end: once you capture the true opcodes for
/// your unit (via the GATT Explorer / sniffing), adjust the values here and the
/// ANC toggle will drive hardware with no other changes.
///
/// Frame layout used here: `[ SOF, opcode, payloadLen, payload..., checksum ]`
enum BeoCommand {
    static let startOfFrame: UInt8 = 0xBE   // mnemonic for "B&O"

    enum Opcode: UInt8 {
        case setANCMode = 0x10
        case setTransparency = 0x11
    }

    /// ANC mode → payload byte.
    static func ancPayload(_ mode: ANCMode) -> UInt8 {
        switch mode {
        case .off: return 0x00
        case .on: return 0x01
        case .transparency: return 0x02
        case .adaptive: return 0x03
        }
    }

    /// Build the ANC command frame for a given mode.
    static func anc(_ mode: ANCMode) -> Data {
        frame(opcode: .setANCMode, payload: [ancPayload(mode)])
    }

    /// Build a transparency-level command frame (0...100%).
    static func transparency(_ level: Double) -> Data {
        let pct = UInt8(max(0, min(100, (level * 100).rounded())))
        return frame(opcode: .setTransparency, payload: [pct])
    }

    /// Assemble `[SOF, opcode, len, payload..., checksum]` with an XOR checksum.
    private static func frame(opcode: Opcode, payload: [UInt8]) -> Data {
        var bytes: [UInt8] = [startOfFrame, opcode.rawValue, UInt8(payload.count)]
        bytes.append(contentsOf: payload)
        let checksum = bytes.reduce(UInt8(0)) { $0 ^ $1 }
        bytes.append(checksum)
        return Data(bytes)
    }
}
