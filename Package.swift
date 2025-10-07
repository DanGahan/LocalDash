// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MenuBarInfo",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "MenuBarInfo",
            resources: [
                .process("Resources")
            ]
        ),
    ]
)
