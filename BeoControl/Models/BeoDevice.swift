import Foundation
import CoreBluetooth

/// A Bang & Olufsen product family we know how to present nicely.
enum BeoProduct: String, CaseIterable, Identifiable {
    case h95 = "Beoplay H95"
    case portal = "Beoplay Portal"
    case unknown = "Bang & Olufsen"

    var id: String { rawValue }

    /// Best-effort identification from the advertised peripheral name.
    static func identify(from name: String?) -> BeoProduct {
        guard let name = name?.lowercased() else { return .unknown }
        if name.contains("h95") { return .h95 }
        if name.contains("portal") { return .portal }
        return .unknown
    }

    /// Whether the advertised name looks like Bang & Olufsen gear, even if we
    /// can't pin down the exact model.
    static func isBangOlufsen(name: String?) -> Bool {
        guard let name = name?.lowercased() else { return false }
        return ["h95", "portal", "beoplay", "beosound", "bang", "b&o", "b & o"]
            .contains { name.contains($0) }
    }

    var systemImage: String {
        switch self {
        case .h95: return "headphones"
        case .portal: return "gamecontroller"
        case .unknown: return "headphones"
        }
    }

    var tagline: String {
        switch self {
        case .h95: return "Adaptive ANC over-ears"
        case .portal: return "Xbox gaming headset"
        case .unknown: return "Bang & Olufsen audio"
        }
    }

    /// Whether this product exposes Xbox Wireless / gaming-specific controls.
    var supportsXbox: Bool { self == .portal }
}

/// A discovered peripheral plus the live state we have collected for it.
final class BeoDevice: Identifiable, ObservableObject {
    let id: UUID
    let peripheral: CBPeripheral
    let product: BeoProduct

    @Published var advertisedName: String
    @Published var rssi: Int
    @Published var connectionState: ConnectionState = .disconnected

    // Live values read over GATT.
    @Published var batteryLevel: Int?          // 0...100, from 0x2A19
    @Published var manufacturer: String?        // 0x2A29
    @Published var modelNumber: String?         // 0x2A24
    @Published var firmwareRevision: String?    // 0x2A26
    @Published var serialNumber: String?        // 0x2A25
    @Published var hardwareRevision: String?    // 0x2A27
    @Published var softwareRevision: String?    // 0x2A28

    // Discovered GATT tree, surfaced through the explorer.
    @Published var services: [GATTService] = []

    /// Characteristic chosen (or auto-detected) as the proprietary B&O control
    /// endpoint. When set, ANC/transparency commands are written here for real.
    @Published var controlCharacteristicUUID: CBUUID?

    /// Remembered active ANC mode so the on/off toggle can restore it.
    var lastActiveANCMode: ANCMode = .adaptive

    /// Control state. For standard-GATT-readable values these reflect reality;
    /// for proprietary B&O control they reflect the last command we attempted.
    @Published var control = ControlState()

    enum ConnectionState: String {
        case disconnected, connecting, connected, discovering, ready, failed
    }

    init(peripheral: CBPeripheral, advertisedName: String?, rssi: Int) {
        self.id = peripheral.identifier
        self.peripheral = peripheral
        self.advertisedName = advertisedName ?? peripheral.name ?? "Unknown device"
        self.rssi = rssi
        self.product = BeoProduct.identify(from: advertisedName ?? peripheral.name)
    }

    var displayName: String {
        if product != .unknown { return product.rawValue }
        return advertisedName
    }
}

/// Discovered service node for the GATT explorer.
struct GATTService: Identifiable {
    let id = UUID()
    let uuid: CBUUID
    var characteristics: [GATTCharacteristic]
    var name: String { KnownUUID.name(for: uuid) ?? "Service \(uuid.uuidString)" }
}

/// Discovered characteristic node for the GATT explorer.
struct GATTCharacteristic: Identifiable {
    let id = UUID()
    let uuid: CBUUID
    let properties: CBCharacteristicProperties
    var lastValue: Data?
    var isNotifying: Bool = false
    var name: String { KnownUUID.name(for: uuid) ?? "Characteristic \(uuid.uuidString)" }

    var propertyDescription: String {
        var parts: [String] = []
        if properties.contains(.read) { parts.append("Read") }
        if properties.contains(.write) { parts.append("Write") }
        if properties.contains(.writeWithoutResponse) { parts.append("WriteNR") }
        if properties.contains(.notify) { parts.append("Notify") }
        if properties.contains(.indicate) { parts.append("Indicate") }
        return parts.isEmpty ? "—" : parts.joined(separator: " · ")
    }

    var canWrite: Bool {
        properties.contains(.write) || properties.contains(.writeWithoutResponse)
    }
    var canRead: Bool { properties.contains(.read) }
    var canNotify: Bool {
        properties.contains(.notify) || properties.contains(.indicate)
    }
}
