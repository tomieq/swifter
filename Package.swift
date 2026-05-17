// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "Swifter",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15)
    ],

    products: [
        .library(name: "Swifter", targets: ["Swifter"]),
        .executable(name: "Example", targets: ["Example"])
    ],

    dependencies: [],

    targets: [
        .target(
            name: "Swifter",
            dependencies: [],
            path: "Sources"
        ),

        .executableTarget(
            name: "Example",
            dependencies: [
                "Swifter"
            ],
            path: "Example"),

        .testTarget(
            name: "SwifterTests",
            dependencies: [
                "Swifter"
            ],
            path: "Tests"
        )
    ]
)
