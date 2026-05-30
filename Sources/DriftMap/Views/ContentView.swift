import SwiftUI

struct ContentView: View {
    @State private var viewModel = HeatmapPreviewViewModel()

    var body: some View {
        FloatingControls(viewModel: viewModel)
            .padding(8)
            .fixedSize()
            .background(Color.clear)
            .background(WindowConfigurator())
            .onAppear {
                viewModel.startOverlayMode()
            }
            .onDisappear {
                viewModel.stopOverlayMode()
            }
    }
}

#Preview {
    ContentView()
}
