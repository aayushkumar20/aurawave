// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AuraMusic",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "AuraMusic",
            targets: ["AuraMusic"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "AuraMusic",
            path: "AuraMusic",
            exclude: ["Info.plist"]
        )
    ]
)
