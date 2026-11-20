// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Syllabi",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Syllabi", targets: ["Syllabi"])
    ],
    targets: [
        .executableTarget(
            name: "Syllabi",
            path: "Syllabi",
            exclude: ["Info.plist", "Syllabi.entitlements", "Resources"]
        ),
        .testTarget(
            name: "SyllabiTests",
            dependencies: ["Syllabi"],
            path: "Tests"
        )
    ]
)
