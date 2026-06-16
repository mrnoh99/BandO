import SwiftUI

struct AboutView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("BandO").font(.largeTitle.bold())
                        Text("A control app for Bang & Olufsen Beoplay H95 and Beoplay Portal (Xbox) headphones.")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }

                Section("What works over real Bluetooth LE") {
                    bullet("Scan, connect and discover the full GATT tree", "antenna.radiowaves.left.and.right")
                    bullet("Live battery level (Battery Service 0x180F)", "battery.75percent")
                    bullet("Device info — model, firmware, serial (0x180A)", "info.circle")
                    bullet("Read / write / subscribe any characteristic", "arrow.left.arrow.right")
                }

                Section("How proprietary control works") {
                    Text("Bang & Olufsen's ANC, EQ and gaming controls use a proprietary protocol that largely runs over Bluetooth Classic (RFCOMM), which iOS does not expose to non-MFi apps. The control surface in this app updates device state and is ready to encode commands — map the reverse-engineered control characteristic into BeoGATT, and the GATT Explorer lets you drive it directly with raw writes.")
                        .font(.callout)
                }

                Section("Privacy") {
                    Text("All Bluetooth communication is local between your iPhone and your headphones. Nothing is sent off-device.")
                        .font(.callout)
                }
            }
            .navigationTitle("About")
        }
    }

    private func bullet(_ text: String, _ symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .labelStyle(.titleAndIcon)
            .font(.callout)
    }
}
