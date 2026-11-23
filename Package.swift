// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "RRULE",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .tvOS(.v16),
        .watchOS(.v9),
        .visionOS(.v1),
    ],
    products: [
        .library(
            name: "RRULE",
            targets: ["RRULE"]
        )
    ],
    targets: [
        .target(
            name: "RRULE",
            dependencies: []
        ),
        .testTarget(
            name: "RRULETests",
            dependencies: ["RRULE"],
            resources: [.copy("Resources/dateutil-fixture.json")]
        ),
    ]
)
