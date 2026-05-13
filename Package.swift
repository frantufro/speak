// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "speak",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "SpeakKit", targets: ["SpeakKit"]),
        .library(name: "SpeakPlatform", targets: ["SpeakPlatform"]),
        .library(name: "SpeakSTT", targets: ["SpeakSTT"]),
        .executable(name: "SpeakApp", targets: ["SpeakApp"]),
    ],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.9.0"),
    ],
    targets: [
        .target(name: "SpeakKit", path: "Sources/SpeakKit"),
        .target(
            name: "SpeakPlatform",
            dependencies: ["SpeakKit"],
            path: "Sources/SpeakPlatform"
        ),
        .target(
            name: "SpeakSTT",
            dependencies: [
                "SpeakKit",
                .product(name: "WhisperKit", package: "WhisperKit"),
            ],
            path: "Sources/SpeakSTT"
        ),
        .executableTarget(
            name: "SpeakApp",
            dependencies: ["SpeakKit", "SpeakPlatform", "SpeakSTT"],
            path: "Sources/SpeakApp"
        ),
        .testTarget(
            name: "SpeakKitTests",
            dependencies: ["SpeakKit"],
            path: "Tests/SpeakKitTests"
        ),
    ]
)
