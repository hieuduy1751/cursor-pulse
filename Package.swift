// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CursorPulse",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "CursorPulse",
            dependencies: ["CursorPulseCore"],
            resources: [.copy("Resources")]
        ),
        .target(name: "CursorPulseCore"),
        .executableTarget(
            name: "cursorpulse-report",
            dependencies: ["CursorPulseCore"]
        ),
    ]
)
