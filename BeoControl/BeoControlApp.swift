import SwiftUI

@main
struct BeoControlApp: App {
    @StateObject private var bluetooth = BluetoothManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(bluetooth)
                .preferredColorScheme(.dark)
                .tint(.beoAccent)
        }
    }
}
