// swift-tools-version:5.9

import PackageDescription

let development = true

let package = Package(
  name: "Swifter",
  platforms: [
    .macOS(.v10_15)
  ],
  products: [
    .library(name: "Swifter", targets: ["Swifter"]),
    .executable(name: "Example", targets: ["Example"])
  ],

  dependencies: [
    .package(url: "https://github.com/tomieq/SwiftExtensions", branch: "master"),
    .package(url: "https://github.com/apple/swift-crypto.git", .upToNextMajor(from: "3.12.3")),
  ],

  targets: [
    .target(
      name: "Swifter", 
      dependencies: [
        .product(name: "SwiftExtensions", package: "SwiftExtensions"),
        .product(name: "Crypto", package: "swift-crypto")
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
