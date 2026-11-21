// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MacTouchDesktop",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "MacTouchDesktop", targets: ["MacTouchDesktop"]),
        .library(name: "MacTouchCore", targets: ["MacTouchCore"]),
    ],
    targets: [
        // UI-free: protocol, crypto, pairing, WebSocket server. Unit-testable.
        .target(name: "MacTouchCore"),
        // SwiftUI app.
        .executableTarget(name: "MacTouchDesktop", dependencies: ["MacTouchCore"]),
        .testTarget(name: "MacTouchCoreTests", dependencies: ["MacTouchCore"]),
    ]
)
