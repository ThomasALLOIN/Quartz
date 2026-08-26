// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Quartz",
    defaultLocalization: "fr",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "QuartzKit", targets: ["QuartzKit"]),
        .executable(name: "QuartzPreview", targets: ["QuartzApp"]),
        .executable(name: "QuartzChecks", targets: ["QuartzChecks"]),
        .executable(name: "quartz", targets: ["QuartzCLI"])
    ],
    targets: [
        .target(name: "QuartzKit"),
        .executableTarget(
            name: "QuartzApp",
            dependencies: ["QuartzKit"],
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "QuartzChecks",
            dependencies: ["QuartzKit"]
        ),
        .executableTarget(
            name: "QuartzCLI",
            dependencies: ["QuartzKit"]
        )
    ]
)
