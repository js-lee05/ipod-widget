// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "iPodWidget",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "IPodCore"),
        .executableTarget(name: "iPodWidget", dependencies: ["IPodCore"]),
        .testTarget(name: "IPodCoreTests", dependencies: ["IPodCore"]),
    ]
)
