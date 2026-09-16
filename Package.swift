// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacAppCleaner",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "MacAppCleanerKit",
            targets: ["MacAppCleanerKit"]
        ),
        .executable(
            name: "MacAppCleaner",
            targets: ["MacAppCleaner"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "MacAppCleanerKit",
            dependencies: [],
            path: "Sources/MacAppCleanerKit"
        ),
        .executableTarget(
            name: "MacAppCleaner",
            dependencies: ["MacAppCleanerKit"],
            path: "Sources/MacAppCleaner",
            exclude: ["Resources"]
        ),
        .testTarget(
            name: "MacAppCleanerTests",
            dependencies: ["MacAppCleanerKit"],
            path: "Tests/MacAppCleanerTests"
        )
    ]
)
