// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Joypad",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "Joypad",
            path: "Sources/Joypad"
        )
    ]
)
