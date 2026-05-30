import SwiftUI

struct HeatmapOverlayView: View {
    let viewModel: HeatmapPreviewViewModel
    let displayID: UInt32

    var body: some View {
        HeatmapCanvas(
            samples: viewModel.overlaySamples(for: displayID),
            showsGrid: false,
            showsCursorPoints: false
        )
        .background(Color.clear)
        .ignoresSafeArea()
    }
}
