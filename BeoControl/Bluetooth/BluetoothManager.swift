import Foundation
import CoreBluetooth
import Combine

/// Real CoreBluetooth controller: scans for peripherals, connects, discovers the
/// full GATT tree, keeps standard values (battery, device info) live, and exposes
/// generic read/write/subscribe so proprietary B&O characteristics can be driven.
@MainActor
final class BluetoothManager: NSObject, ObservableObject {

    @Published var state: CBManagerState = .unknown
    @Published var isScanning = false
    @Published var devices: [BeoDevice] = []
    @Published var log: [LogEntry] = []

    /// When true we only surface peripherals that look like Bang & Olufsen gear.
    @Published var onlyShowBeo = true

    private var central: CBCentralManager!
    /// Strong references to peripherals we are talking to (CoreBluetooth keeps weak refs).
    private var connected: [UUID: BeoDevice] = [:]

    struct LogEntry: Identifiable {
        let id = UUID()
        let date = Date()
        let level: Level
        let message: String
        enum Level { case info, success, warning, error, traffic }
    }

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: nil)
    }

    // MARK: - Logging

    private func log(_ message: String, _ level: LogEntry.Level = .info) {
        log.insert(LogEntry(level: level, message: message), at: 0)
        if log.count > 300 { log.removeLast(log.count - 300) }
    }

    // MARK: - Scanning

    func startScan() {
        guard central.state == .poweredOn else {
            log("Cannot scan — Bluetooth is \(state.description).", .warning)
            return
        }
        devices.removeAll { $0.connectionState == .disconnected }
        isScanning = true
        log("Scanning for nearby devices…", .info)
        central.scanForPeripherals(
            withServices: BeoGATT.scanFilter,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }

    func stopScan() {
        guard isScanning else { return }
        central.stopScan()
        isScanning = false
        log("Stopped scanning.", .info)
    }

    // MARK: - Connection

    func connect(_ device: BeoDevice) {
        stopScan()
        device.connectionState = .connecting
        connected[device.id] = device
        device.peripheral.delegate = self
        log("Connecting to \(device.displayName)…", .info)
        central.connect(device.peripheral, options: nil)
    }

    func disconnect(_ device: BeoDevice) {
        log("Disconnecting from \(device.displayName)…", .info)
        central.cancelPeripheralConnection(device.peripheral)
    }

    // MARK: - High-level control

    /// Set the active noise-control mode. Updates state and, if a control
    /// characteristic is mapped, writes the encoded command to hardware.
    func setANCMode(_ mode: ANCMode, on device: BeoDevice) {
        device.control.ancMode = mode
        sendControl(BeoCommand.anc(mode), intent: "ANC → \(mode.rawValue)", on: device)
    }

    /// Convenience on/off toggle: flips between Off and the last active mode.
    func toggleANC(on device: BeoDevice) {
        if device.control.ancMode == .off {
            setANCMode(device.lastActiveANCMode, on: device)
        } else {
            device.lastActiveANCMode = device.control.ancMode
            setANCMode(.off, on: device)
        }
    }

    /// Set the ANC↔transparency blend (0 = full ANC ... 1 = full transparency).
    func setTransparency(_ level: Double, on device: BeoDevice) {
        device.control.transparencyLevel = level
        sendControl(BeoCommand.transparency(level),
                    intent: "Transparency → \(Int(level * 100))%", on: device)
    }

    /// Resolve the mapped control characteristic and write, or log intent only.
    private func sendControl(_ payload: Data, intent: String, on device: BeoDevice) {
        guard let uuid = device.controlCharacteristicUUID,
              let node = characteristicNode(uuid, on: device) else {
            log("\(intent) — saved (no control characteristic mapped yet; map one in GATT Explorer to deliver to hardware).", .warning)
            return
        }
        write(payload, to: node, on: device)
        log("\(intent) — sent \(payload.hexString) to \(node.name).", .success)
    }

    /// Mark a characteristic as the proprietary control endpoint.
    func setControlCharacteristic(_ characteristic: GATTCharacteristic, on device: BeoDevice) {
        device.controlCharacteristicUUID = characteristic.uuid
        log("Control characteristic set to \(characteristic.name).", .success)
    }

    private func characteristicNode(_ uuid: CBUUID, on device: BeoDevice) -> GATTCharacteristic? {
        for service in device.services {
            if let match = service.characteristics.first(where: { $0.uuid == uuid }) {
                return match
            }
        }
        return nil
    }

    /// Heuristic: pick a likely control endpoint — a writable characteristic in a
    /// vendor-specific (128-bit) service — so the ANC toggle can attempt a real
    /// write without manual mapping. The user can override in the explorer.
    private func autoDetectControlCharacteristic(for device: BeoDevice) {
        guard device.controlCharacteristicUUID == nil else { return }
        for service in device.services where service.uuid.uuidString.count > 4 {
            if let candidate = service.characteristics.first(where: {
                $0.canWrite && $0.uuid.uuidString.count > 4
            }) {
                device.controlCharacteristicUUID = candidate.uuid
                log("Auto-selected control characteristic candidate \(candidate.name). Verify in GATT Explorer.", .info)
                return
            }
        }
    }

    // MARK: - Generic GATT operations (used by control layer + explorer)

    func read(_ characteristic: GATTCharacteristic, on device: BeoDevice) {
        guard let cbChar = cbCharacteristic(characteristic, on: device) else { return }
        device.peripheral.readValue(for: cbChar)
        log("Read \(characteristic.name)", .traffic)
    }

    func setNotify(_ enabled: Bool, for characteristic: GATTCharacteristic, on device: BeoDevice) {
        guard let cbChar = cbCharacteristic(characteristic, on: device) else { return }
        device.peripheral.setNotifyValue(enabled, for: cbChar)
        log("\(enabled ? "Subscribe" : "Unsubscribe") \(characteristic.name)", .traffic)
    }

    func write(_ data: Data, to characteristic: GATTCharacteristic, on device: BeoDevice) {
        guard let cbChar = cbCharacteristic(characteristic, on: device) else { return }
        let type: CBCharacteristicWriteType =
            characteristic.properties.contains(.write) ? .withResponse : .withoutResponse
        device.peripheral.writeValue(data, for: cbChar, type: type)
        log("Write \(data.hexString) → \(characteristic.name)", .traffic)
    }

    /// Resolve our value-type characteristic node back to the live CBCharacteristic.
    private func cbCharacteristic(_ node: GATTCharacteristic, on device: BeoDevice) -> CBCharacteristic? {
        guard let services = device.peripheral.services else { return nil }
        for service in services {
            if let match = service.characteristics?.first(where: { $0.uuid == node.uuid }) {
                return match
            }
        }
        log("Characteristic \(node.name) not found on peripheral.", .warning)
        return nil
    }

    // MARK: - Tree rebuild

    fileprivate func rebuildTree(for device: BeoDevice) {
        guard let services = device.peripheral.services else { return }
        device.services = services.map { service in
            let chars = (service.characteristics ?? []).map { c in
                GATTCharacteristic(
                    uuid: c.uuid,
                    properties: c.properties,
                    lastValue: c.value,
                    isNotifying: c.isNotifying
                )
            }
            return GATTService(uuid: service.uuid, characteristics: chars)
        }
        autoDetectControlCharacteristic(for: device)
    }
}

// MARK: - CBCentralManagerDelegate

extension BluetoothManager: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let newState = central.state
        Task { @MainActor in
            self.state = newState
            self.log("Bluetooth state: \(newState.description)",
                     newState == .poweredOn ? .success : .warning)
            if newState == .poweredOn { self.startScan() }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager,
                                    didDiscover peripheral: CBPeripheral,
                                    advertisementData: [String: Any],
                                    rssi RSSI: NSNumber) {
        let advName = (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? peripheral.name
        let rssi = RSSI.intValue
        Task { @MainActor in
            if self.onlyShowBeo && !BeoProduct.isBangOlufsen(name: advName) { return }

            if let existing = self.devices.first(where: { $0.id == peripheral.identifier }) {
                existing.rssi = rssi
                if let advName { existing.advertisedName = advName }
            } else {
                let device = BeoDevice(peripheral: peripheral, advertisedName: advName, rssi: rssi)
                self.devices.append(device)
                self.log("Discovered \(device.displayName) (RSSI \(rssi))", .success)
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            guard let device = self.connected[peripheral.identifier] else { return }
            device.connectionState = .discovering
            self.log("Connected to \(device.displayName). Discovering services…", .success)
            peripheral.discoverServices(nil)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager,
                                    didFailToConnect peripheral: CBPeripheral,
                                    error: Error?) {
        Task { @MainActor in
            guard let device = self.connected[peripheral.identifier] else { return }
            device.connectionState = .failed
            self.log("Failed to connect: \(error?.localizedDescription ?? "unknown error")", .error)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager,
                                    didDisconnectPeripheral peripheral: CBPeripheral,
                                    error: Error?) {
        Task { @MainActor in
            guard let device = self.connected[peripheral.identifier] else { return }
            device.connectionState = .disconnected
            device.services = []
            self.connected[peripheral.identifier] = nil
            self.log("Disconnected from \(device.displayName).",
                     error == nil ? .info : .warning)
        }
    }
}

// MARK: - CBPeripheralDelegate

extension BluetoothManager: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        Task { @MainActor in
            guard let device = self.connected[peripheral.identifier] else { return }
            if let error {
                self.log("Service discovery error: \(error.localizedDescription)", .error)
                return
            }
            let services = peripheral.services ?? []
            self.log("Found \(services.count) services.", .info)
            for service in services {
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral,
                                didDiscoverCharacteristicsFor service: CBService,
                                error: Error?) {
        Task { @MainActor in
            guard let device = self.connected[peripheral.identifier] else { return }
            if let error {
                self.log("Characteristic discovery error: \(error.localizedDescription)", .error)
                return
            }
            self.rebuildTree(for: device)

            for characteristic in service.characteristics ?? [] {
                // Auto-read all readable standard values.
                if characteristic.properties.contains(.read) {
                    peripheral.readValue(for: characteristic)
                }
                // Auto-subscribe to battery so it stays live.
                if characteristic.uuid == BeoGATT.batteryLevel,
                   characteristic.properties.contains(.notify) {
                    peripheral.setNotifyValue(true, for: characteristic)
                }
            }

            // Once we've discovered the standard services, mark ready.
            if service.uuid == BeoGATT.deviceInformationService
                || service.uuid == BeoGATT.batteryService {
                if device.connectionState != .ready {
                    device.connectionState = .ready
                    self.log("\(device.displayName) ready.", .success)
                }
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral,
                                didUpdateValueFor characteristic: CBCharacteristic,
                                error: Error?) {
        let uuid = characteristic.uuid
        let value = characteristic.value
        Task { @MainActor in
            guard let device = self.connected[peripheral.identifier] else { return }
            if let error {
                self.log("Read error on \(uuid.uuidString): \(error.localizedDescription)", .error)
                return
            }
            self.apply(value: value, for: uuid, on: device)
            self.rebuildTree(for: device)
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral,
                                didWriteValueFor characteristic: CBCharacteristic,
                                error: Error?) {
        let uuid = characteristic.uuid
        Task { @MainActor in
            if let error {
                self.log("Write failed on \(uuid.uuidString): \(error.localizedDescription)", .error)
            } else {
                self.log("Write acknowledged on \(KnownUUID.name(for: uuid) ?? uuid.uuidString).", .success)
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral,
                                didUpdateNotificationStateFor characteristic: CBCharacteristic,
                                error: Error?) {
        Task { @MainActor in
            guard let device = self.connected[peripheral.identifier] else { return }
            self.rebuildTree(for: device)
            self.log("Notifications \(characteristic.isNotifying ? "enabled" : "disabled") for \(KnownUUID.name(for: characteristic.uuid) ?? characteristic.uuid.uuidString).", .info)
        }
    }

    /// Map a freshly read characteristic value onto our typed device state.
    private func apply(value: Data?, for uuid: CBUUID, on device: BeoDevice) {
        guard let value else { return }
        switch uuid {
        case BeoGATT.batteryLevel:
            if let byte = value.first {
                device.batteryLevel = Int(byte)
                log("Battery: \(byte)%", .traffic)
            }
        case BeoGATT.manufacturerName:
            device.manufacturer = String(data: value, encoding: .utf8)
        case BeoGATT.modelNumber:
            device.modelNumber = String(data: value, encoding: .utf8)
        case BeoGATT.serialNumber:
            device.serialNumber = String(data: value, encoding: .utf8)
        case BeoGATT.firmwareRevision:
            device.firmwareRevision = String(data: value, encoding: .utf8)
        case BeoGATT.hardwareRevision:
            device.hardwareRevision = String(data: value, encoding: .utf8)
        case BeoGATT.softwareRevision:
            device.softwareRevision = String(data: value, encoding: .utf8)
        default:
            break
        }
    }
}

// MARK: - Helpers

extension CBManagerState {
    var description: String {
        switch self {
        case .poweredOn: return "powered on"
        case .poweredOff: return "powered off"
        case .unauthorized: return "unauthorized"
        case .unsupported: return "unsupported"
        case .resetting: return "resetting"
        case .unknown: return "unknown"
        @unknown default: return "unknown"
        }
    }
}

extension Data {
    var hexString: String {
        map { String(format: "%02X", $0) }.joined(separator: " ")
    }

    /// Parse a hex string like "01 A0 FF" or "01a0ff" into Data.
    init?(hexString: String) {
        let cleaned = hexString
            .replacingOccurrences(of: "0x", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: "")
        guard cleaned.count % 2 == 0 else { return nil }
        var data = Data(capacity: cleaned.count / 2)
        var index = cleaned.startIndex
        while index < cleaned.endIndex {
            let next = cleaned.index(index, offsetBy: 2)
            guard let byte = UInt8(cleaned[index..<next], radix: 16) else { return nil }
            data.append(byte)
            index = next
        }
        self = data
    }
}
