// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SpendKitNative",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.executable(name: "SpendKitNative", targets: ["SpendKitNative"])],
    targets: [
        .executableTarget(name: "SpendKitNative"),
        .testTarget(name: "SpendKitNativeTests", dependencies: ["SpendKitNative"]),
    ]
)
