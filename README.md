# DriftMap

DriftMap is a macOS app for app-scoped cursor heatmaps and overlay generation.

## Requirements

- macOS 14 or newer
- Xcode 26 or newer
- Swift 6

## Development

Build the app:

```sh
make build
```

Run tests:

```sh
make test
```

Launch the app from SwiftPM:

```sh
make run
```

## Project Structure

- `Sources/DriftMap`: SwiftUI macOS app shell.
- `Sources/DriftMapCore`: Cursor sample and heatmap aggregation logic.
- `Tests/DriftMapCoreTests`: Unit tests for core heatmap behavior.

## Next Implementation Areas

- Capture cursor samples with foreground app attribution.
- Add permissions flow for accessibility and screen recording where needed.
- Render transparent overlay windows above selected apps.
- Export heatmap overlays as images or videos.
