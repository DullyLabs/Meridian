// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Meridian",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Meridian"),
        .testTarget(name: "MeridianTests", dependencies: ["Meridian"]),
    ]
)
