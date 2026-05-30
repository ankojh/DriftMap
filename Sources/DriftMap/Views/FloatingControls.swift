import AppKit
import SwiftUI

struct FloatingControls: View {
    @Bindable var viewModel: HeatmapPreviewViewModel
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("Monitor", selection: $viewModel.selectedDisplayID) {
                        ForEach(viewModel.displays) { display in
                            Text(display.label)
                                .tag(display.id)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 220)
                    .onAppear {
                        viewModel.refreshDisplays()
                    }

                    Picker("Record", selection: $viewModel.selectedRecordKey) {
                        Text("All apps")
                            .tag(HeatmapPreviewViewModel.globalRecordKey)

                        ForEach(viewModel.appRecords) { record in
                            Text(record.name)
                                .tag(record.identifier)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 220)

                    HStack(spacing: 10) {
                        Button {
                            viewModel.toggleCapture(canvasSize: NSScreen.main?.visibleFrame.size ?? CGSize(width: 1_440, height: 900))
                        } label: {
                            Image(systemName: viewModel.isCapturing ? "pause.fill" : "record.circle")
                        }
                        .help(viewModel.isCapturing ? "Pause capture" : "Resume capture")

                        Button {
                            viewModel.clearSamples()
                        } label: {
                            Image(systemName: "trash")
                        }
                        .help("Clear samples")

                        Spacer(minLength: 0)
                    }
                }
                .padding(12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.secondary.opacity(0.2), lineWidth: 1)
                }
                .fixedSize()
            }

            Button {
                isExpanded.toggle()
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.bordered)
            .help(isExpanded ? "Hide controls" : "Show controls")
        }
    }
}
