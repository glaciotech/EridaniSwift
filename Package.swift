// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "EridaniSwift",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .visionOS(.v1),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "EridaniSwift",
            targets: ["EridaniSwift"]),
        .library(
            name: "EridaniStorageOptions",
            targets: ["EridaniStorageOptions"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.3.0"),
        .package(url: "https://github.com/ptliddle/swifty-prompts.git", from: "0.5.0"),
        .package(url: "https://github.com/glaciotech/mcp-swift-sdk-helpers.git", from: "0.3.1"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "EridaniSwift",
            dependencies: [
                .product(name: "SwiftyPrompts", package: "swifty-prompts"),
                .product(name: "SwiftyPrompts.Local", package: "swifty-prompts"),
                .product(name: "SwiftyPrompts.OpenAI", package: "swifty-prompts"),
                .product(name: "SwiftyPrompts.Anthropic", package: "swifty-prompts"),
                .product(name: "SwiftyPrompts.xAI", package: "swifty-prompts"),
                .product(name: "SwiftyPrompts.Inception", package: "swifty-prompts"),
                .product(name: "OrderedCollections", package: "swift-collections"),
                
                .product(name: "MCPHelpers", package: "mcp-swift-sdk-helpers"),
            ],
            path: "Sources/EridaniSwift"
        ),
        .target(name: "EridaniStorageOptions",
                dependencies: ["EridaniSwift",
                               .product(name: "OrderedCollections", package: "swift-collections"),
                               .product(name: "Yams", package: "Yams")
            ]),
        .testTarget(
            name: "EridaniSwiftTests",
            dependencies: [
                "EridaniSwift",
                .product(name: "SwiftyPrompts", package: "swifty-prompts"),
                .product(name: "MCPHelpers", package: "mcp-swift-sdk-helpers")
            ],
            resources: [
            ]
        ),
    ]
)
