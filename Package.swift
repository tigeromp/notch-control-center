// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NotchControlCenter",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "NotchControlCenter", targets: ["NotchControlCenter"])
    ],
    targets: [
        .executableTarget(
            name: "NotchControlCenter",
            path: "Sources/NotchControlCenter"
        )
    ]
)
