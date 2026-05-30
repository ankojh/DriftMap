import SwiftUI

struct SettingsView: View {
    var body: some View {
        Form {
            Text("DriftMap is ready for capture, overlay, and export settings.")
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 420, height: 180)
    }
}
