// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SPlayerMenuBarLyrics",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "SPlayerMenuBarLyrics", targets: ["SPlayerMenuBarLyrics"]),
    ],
    targets: [
        .executableTarget(
            name: "SPlayerMenuBarLyrics",
            path: "Sources/SPlayerMenuBarLyrics",
            swiftSettings: [
                .swiftLanguageMode(.v5),
                .define("DEBUG", .when(configuration: .debug)),
            ]
        ),
        .testTarget(
            name: "SPlayerMenuBarLyricsTests",
            dependencies: ["SPlayerMenuBarLyrics"],
            path: "Tests/SPlayerMenuBarLyricsTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
