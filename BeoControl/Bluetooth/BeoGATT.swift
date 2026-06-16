import Foundation
import CoreBluetooth

/// Standard Bluetooth SIG services/characteristics that B&O headphones expose,
/// plus placeholders for the proprietary B&O control service.
///
/// IMPORTANT: Bang & Olufsen's ANC/EQ control runs over a *proprietary* protocol
/// (largely Bluetooth Classic / RFCOMM, which iOS does not expose to non-MFi
/// apps). The standard GATT services below ARE readable over BLE on iOS and
/// give us live battery, device info, and a discovery surface. The proprietary
/// UUIDs are left here so that, once reverse-engineered from your specific unit,
/// you can drop the values in and the explorer/control layer will use them.
enum BeoGATT {
    // Standard SIG services
    static let batteryService          = CBUUID(string: "180F")
    static let deviceInformationService = CBUUID(string: "180A")
    static let genericAccessService    = CBUUID(string: "1800")

    // Standard SIG characteristics
    static let batteryLevel            = CBUUID(string: "2A19")
    static let manufacturerName        = CBUUID(string: "2A29")
    static let modelNumber             = CBUUID(string: "2A24")
    static let serialNumber            = CBUUID(string: "2A25")
    static let firmwareRevision        = CBUUID(string: "2A26")
    static let hardwareRevision        = CBUUID(string: "2A27")
    static let softwareRevision        = CBUUID(string: "2A28")
    static let deviceName              = CBUUID(string: "2A00")

    /// Services we proactively scan for. `nil` here means "discover everything",
    /// which we want so the explorer can surface proprietary services too.
    static let scanFilter: [CBUUID]? = nil
}

/// Friendly names for known UUIDs surfaced in the explorer.
enum KnownUUID {
    private static let table: [String: String] = [
        "1800": "Generic Access",
        "1801": "Generic Attribute",
        "180A": "Device Information",
        "180F": "Battery Service",
        "2A00": "Device Name",
        "2A01": "Appearance",
        "2A19": "Battery Level",
        "2A24": "Model Number",
        "2A25": "Serial Number",
        "2A26": "Firmware Revision",
        "2A27": "Hardware Revision",
        "2A28": "Software Revision",
        "2A29": "Manufacturer Name",
        "2A50": "PnP ID",
    ]

    static func name(for uuid: CBUUID) -> String? {
        table[uuid.uuidString.uppercased()]
    }
}
