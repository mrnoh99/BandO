# BandO — Beoplay H95 & Portal control app

A native **iOS (SwiftUI)** app that discovers and controls **Bang & Olufsen
Beoplay H95** and **Beoplay Portal** (Xbox gaming headset) headphones over
**real Bluetooth LE** using CoreBluetooth.

<p align="center"><i>Scan → Connect → Read live battery & device info → Explore the GATT tree → Drive controls</i></p>

## Features

- **Real BLE discovery & connection** — scans for nearby peripherals, filters to
  Bang & Olufsen gear, connects and discovers the full GATT tree.
- **Live battery level** read & subscribed from the standard Battery Service
  (`0x180F` / `0x2A19`).
- **Device info** — manufacturer, model, firmware, serial, hardware/software
  revisions from the Device Information Service (`0x180A`).
- **Control surface** for both products:
  - Noise control: Off / Active / Transparency / Adaptive, with an
    ANC↔Transparency blend slider.
  - Sound: volume, tone presets, bass & treble.
  - **Portal / Xbox extras**: Xbox Wireless toggle, Dolby Atmos, microphone
    routing (boom / virtual boom / mute), game–chat balance, sidetone.
- **GATT Explorer** — inspect every service/characteristic, **read**, **write
  raw hex**, and **subscribe** to notifications. This is the surface for driving
  B&O's proprietary control once a characteristic is identified.
- **Activity log** of all Bluetooth events and GATT traffic.

## Requirements

- Xcode 16 or newer (the project uses file-system-synchronized groups,
  `objectVersion = 77`).
- iOS 17.0+ device. **Bluetooth LE requires a real device — it does not work in
  the Simulator.**

## Build & run

```bash
open BandO.xcodeproj
```

1. Select the **BeoControl** scheme and your iPhone as the run destination.
2. Set your signing **Team** (target → Signing & Capabilities) — automatic
   signing is enabled.
3. Run. On first launch iOS will ask for **Bluetooth permission** (the usage
   strings are configured in the build settings).

## How real-hardware control works (and its limits)

| Capability | Transport | Status in this app |
|---|---|---|
| Battery level | Standard BLE GATT | ✅ Read live |
| Device info (model/firmware/serial) | Standard BLE GATT | ✅ Read live |
| Discover all services/characteristics | BLE GATT | ✅ Full explorer |
| **ANC toggle / mode / transparency** | **Proprietary B&O protocol (mostly Bluetooth Classic / RFCOMM)** | ⚙️ Encoded & written over BLE to the mapped control characteristic |
| EQ / gaming control | Proprietary B&O protocol | ⚠️ UI ready; reuse the same write path |

Bang & Olufsen's noise-control, EQ and gaming features run over a **proprietary
protocol** that largely uses **Bluetooth Classic (RFCOMM)**. iOS does **not**
expose Bluetooth Classic to third-party apps unless the accessory is part of
Apple's **MFi** program, so those commands cannot be delivered purely over BLE
from an unprivileged app.

This app takes the honest "attempt real BLE" path:

1. Everything that *is* available over standard BLE is read live.
2. The full GATT tree is surfaced so you can discover any custom B&O BLE
   service your specific unit exposes.
3. The **GATT Explorer** lets you write raw bytes and subscribe to
   notifications — the practical way to reverse-engineer and then drive real
   control.

### ANC toggle — the real write path

The noise-control toggle is wired end-to-end over BLE:

1. `ANCControl` calls `BluetoothManager.toggleANC` / `setANCMode`.
2. `BeoCommand.anc(_:)` encodes the mode into a `[SOF, opcode, len, payload,
   checksum]` frame.
3. The frame is written to the device's **control characteristic** via
   `BluetoothManager.write(_:to:on:)`.

The control characteristic is **auto-detected** (first writable characteristic
in a vendor-specific 128-bit service) and can be overridden in **GATT Explorer →
"Use for control"**. Until the true opcodes for your unit are confirmed, the
frame values in `BeoCommand.swift` are clearly-marked placeholders — capture the
real ones with the explorer and edit that one file; nothing else changes.

If no control characteristic is mapped, ANC changes are saved to state and the
UI tells you so, rather than silently doing nothing.

## Project layout

```
BandO.xcodeproj/                 Xcode 16 project (synchronized groups)
BeoControl/
  BeoControlApp.swift            App entry point
  Models/
    BeoDevice.swift              Discovered device + live state + GATT nodes
    ControlState.swift           ANC / EQ / Portal control models
  Bluetooth/
    BeoGATT.swift                Known SIG UUIDs + extension points
    BeoCommand.swift             Encodes ANC/transparency command frames
    BluetoothManager.swift       CoreBluetooth central (scan/connect/GATT/control)
  Views/
    ContentView.swift            Tab shell
    ScanView.swift               Device discovery list
    DeviceDetailView.swift       Per-device control surface
    GATTExplorerView.swift       Raw read/write/subscribe
    ActivityLogView.swift        Live event log
    AboutView.swift              Capabilities & privacy
    Components/                  Control sections, badges
  Assets.xcassets/               App icon + accent color
```

## Privacy

All Bluetooth communication is local between the iPhone and the headphones.
Nothing is sent off-device.
