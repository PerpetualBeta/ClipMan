// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClipMan",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0")
    ],
    targets: [
        .executableTarget(
            name: "ClipMan",
            dependencies: [
                "KeyboardShortcuts"
            ],
            path: "Sources/ClipMan",
            resources: [
                .copy("../../Resources/Info.plist")
            ]
        )
    ]
)
