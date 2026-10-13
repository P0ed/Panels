// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Panels",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "Panels",
            path: "Panels",
            exclude: ["PanelsApp.swift", "View", "Assets.xcassets", "Info.plist"],
            resources: [.copy("Resources")]
        ),
        .testTarget(name: "PanelsTests", dependencies: ["Panels"], path: "PanelsTests"),
    ]
)
