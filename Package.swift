// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DisplayFocus",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "DisplayFocusCore", targets: ["DisplayFocusCore"]),
        .executable(name: "DisplayFocus", targets: ["DisplayFocus"]),
        .executable(name: "DisplayFocusSelfCheck", targets: ["DisplayFocusSelfCheck"]),
    ],
    targets: [
        .target(name: "DisplayFocusCore"),
        .executableTarget(name: "DisplayFocusSelfCheck", dependencies: ["DisplayFocusCore"]),
        .executableTarget(
            name: "DisplayFocus",
            dependencies: ["DisplayFocusCore"],
            exclude: ["Info.plist"],
            resources: [.process("Resources")],
            linkerSettings: [
                .linkedFramework("ApplicationServices"),
                .linkedFramework("Carbon"),
            ]
        ),
    ]
)
