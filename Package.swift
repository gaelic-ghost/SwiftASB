// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftASB",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "SwiftASB",
            targets: ["SwiftASB"]
        ),
        .library(
            name: "ASBPresentation",
            targets: ["ASBPresentation"]
        ),
        .library(
            name: "ASBAppKit",
            targets: ["ASBAppKit"]
        ),
        .library(
            name: "ASBSwiftUI",
            targets: ["ASBSwiftUI"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.1.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SwiftASB",
            dependencies: [
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
            ]
        ),
        .target(
            name: "ASBPresentation",
            dependencies: ["SwiftASB"]
        ),
        .target(
            name: "ASBAppKit",
            dependencies: ["ASBPresentation", "SwiftASB"]
        ),
        .target(
            name: "ASBSwiftUI",
            dependencies: ["ASBAppKit", "ASBPresentation", "SwiftASB"]
        ),
        .testTarget(
            name: "SwiftASBTests",
            dependencies: ["SwiftASB"]
        ),
        .testTarget(
            name: "ASBPresentationTests",
            dependencies: ["ASBPresentation"]
        ),
        .testTarget(
            name: "ASBAppKitTests",
            dependencies: ["ASBAppKit", "ASBPresentation"]
        ),
        .testTarget(
            name: "ASBSwiftUITests",
            dependencies: ["ASBAppKit", "ASBPresentation", "ASBSwiftUI"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
