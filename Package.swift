// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "BrowserSwitch",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "BrowserSwitch", targets: ["BrowserSwitch"])],
    targets: [
        .target(name: "BrowserSwitchCore"),
        .executableTarget(name: "BrowserSwitch", dependencies: ["BrowserSwitchCore"]),
        .testTarget(name: "BrowserSwitchCoreTests", dependencies: ["BrowserSwitchCore"])
    ]
)
