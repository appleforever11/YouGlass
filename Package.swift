// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "YouGlass",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "YouGlass", targets: ["YouTubeMac"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle.git", exact: "2.9.5")
    ],
    targets: [
        .executableTarget(
            name: "YouTubeMac",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/YouTubeMac",
            exclude: [
                "Info.plist"
            ],
            resources: [.copy("Resources")]
        ),
        .testTarget(
            name: "YouTubeMacTests",
            dependencies: ["YouTubeMac"]
        )
    ]
)
