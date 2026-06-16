import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var bluetooth: BluetoothManager

    var body: some View {
        TabView {
            ScanView()
                .tabItem { Label("Devices", systemImage: "headphones") }

            ActivityLogView()
                .tabItem { Label("Activity", systemImage: "list.bullet.rectangle") }

            AboutView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(BluetoothManager())
        .preferredColorScheme(.dark)
}
