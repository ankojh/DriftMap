import SwiftUI

struct ContentView: View {
    @State private var viewModel = HeatmapPreviewViewModel()

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            HeatmapPreview(viewModel: viewModel)
                .background(Color(nsColor: .windowBackgroundColor))

            FloatingControls(viewModel: viewModel)
                .padding(18)
        }
        .background(WindowConfigurator())
    }
}

#Preview {
    ContentView()
}
