// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Noizee",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v26),
    ],
    products: [
        .executable(
            name: "Noizee",
            targets: ["Noizee"]
        ),
        .executable(
            name: "api-explorer",
            targets: ["APIExplorer"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.8.1"),
    ],
    targets: [
        // Main app executable
        .executableTarget(
            name: "Noizee",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            resources: [
                .process("Resources"),
                .copy("Extensions"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
        // API Explorer CLI tool
        .executableTarget(
            name: "APIExplorer",
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        // Unit tests
        .testTarget(
            name: "NoizeeTests",
            dependencies: ["Noizee"],
            resources: [
                .process("Fixtures"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
