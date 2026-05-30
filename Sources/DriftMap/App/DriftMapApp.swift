import SwiftUI

@main
struct DriftMapApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 960, minHeight: 640)
        }
        .windowStyle(.titleBar)

        Settings {
            SettingsView()
        }
    }
}
