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
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.1")
    ],
    targets: [
        .executableTarget(
            name: "Syllabi",
            dependencies: [.product(name: "Sparkle", package: "Sparkle")],
            path: "Syllabi",
            exclude: ["Info.plist", "Syllabi.entitlements", "Resources"],
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
        ),
        .testTarget(
            name: "SyllabiTests",
            dependencies: ["Syllabi"],
            path: "Tests"
        )
    ]
)
