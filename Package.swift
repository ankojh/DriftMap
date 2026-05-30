// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "DriftMap",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "DriftMap", targets: ["DriftMap"]),
        .library(name: "DriftMapCore", targets: ["DriftMapCore"])
    ],
    targets: [
        .executableTarget(
            name: "DriftMap",
            dependencies: ["DriftMapCore"],
            path: "Sources/DriftMap",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny")
            ]
        ),
        .target(
            name: "DriftMapCore",
            path: "Sources/DriftMapCore",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny")
            ]
        ),
        .testTarget(
            name: "DriftMapCoreTests",
            dependencies: ["DriftMapCore"],
            path: "Tests/DriftMapCoreTests"
        )
    ]
)
