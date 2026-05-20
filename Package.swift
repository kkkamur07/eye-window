// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EyeWindow",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "EyeWindowCore", targets: ["EyeWindowCore"]),
        .executable(name: "EyeWindow", targets: ["EyeWindow"]),
        .executable(name: "EyeWindowCoreSelfCheck", targets: ["EyeWindowCoreSelfCheck"]),
        .executable(name: "GazeSmokeTest", targets: ["GazeSmokeTest"]),
    ],
    targets: [
        .target(
            name: "EyeWindowCore",
            resources: [
                .copy("Resources/GazeModel/MobileNetV2Gaze.mlpackage"),
            ],
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("CoreML"),
            ]
        ),
        .executableTarget(
            name: "EyeWindow",
            dependencies: ["EyeWindowCore"],
            exclude: ["Info.plist"],
            linkerSettings: [
                .linkedFramework("ApplicationServices"),
                .linkedFramework("Carbon"),
            ]
        ),
        .executableTarget(
            name: "EyeWindowCoreSelfCheck",
            dependencies: ["EyeWindowCore"]
        ),
        .executableTarget(
            name: "GazeSmokeTest",
            dependencies: ["EyeWindowCore"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("CoreML"),
            ]
        ),
    ]
)
