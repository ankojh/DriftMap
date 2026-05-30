import SwiftUI

@main
struct DriftMapApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(width: 92, height: 48)
        }
        .windowStyle(.hiddenTitleBar)

        Settings {
            SettingsView()
        }
    }
}
