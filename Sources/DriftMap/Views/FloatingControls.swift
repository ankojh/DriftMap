import SwiftUI

struct FloatingControls: View {
    @Bindable var viewModel: HeatmapPreviewViewModel

    var body: some View {
        HStack(spacing: 8) {
            Button {
                viewModel.toggleOverlay()
            } label: {
                Image(systemName: viewModel.isOverlayActive ? "eye" : "eye.slash")
                    .frame(width: 24, height: 24)
            }
            .help(viewModel.isOverlayActive ? "Disable overlay" : "Enable overlay")

            Button {
                viewModel.clearSamples()
            } label: {
                Image(systemName: "trash")
                    .frame(width: 24, height: 24)
            }
            .help("Delete all heatmaps")
        }
        .padding(6)
        .background(.regularMaterial, in: Capsule())
        .buttonStyle(.plain)
    }
}
