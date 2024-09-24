// swift-tools-version:5.2

import PackageDescription

let package = Package(
    name: "WebArchiver",
    products: [
        .library(
            name: "WebArchiver",
            targets: ["WebArchiver"]),
    ],
    targets: [
        .target(
            name: "WebArchiver"),
        .testTarget(
            name: "WebArchiverTests",
            dependencies: ["WebArchiver"]),
    ]
)
