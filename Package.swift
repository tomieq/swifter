// swift-tools-version:5.9

import PackageDescription

let package = Package(
  name: "Swifter",

  products: [
    .library(name: "Swifter", targets: ["Swifter"]),
    .executable(name: "Example", targets: ["Example"])
  ],

  dependencies: [
    .package(url: "https://github.com/tomieq/SwiftExtensions", branch: "master")
  ],

  targets: [
    .target(
      name: "Swifter", 
      dependencies: [
        .product(name: "SwiftExtensions", package: "SwiftExtensions")
      ],
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
