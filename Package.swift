// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "Swifter",

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
