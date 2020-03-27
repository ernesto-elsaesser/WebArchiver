// swift-tools-version:5.2

import PackageDescription

let package = Package(
    name: "WebArchiver",
    products: [
        .library(
            name: "WebArchiver",
            targets: ["WebArchiver"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/cezheng/Fuzi",
            from: "3.1.2")
    ],
    targets: [
        .target(
            name: "WebArchiver",
            dependencies: ["Fuzi"]),
        .testTarget(
            name: "WebArchiverTests",
            dependencies: ["WebArchiver"]),
    ]
)
