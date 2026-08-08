// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "snap-syphon",
  platforms: [
    .macOS(.v13),
  ],
  products: [
    .executable(name: "snap-syphon", targets: ["SnapSyphon"]),
  ],
  dependencies: [
    .package(
      url: "https://github.com/apple/swift-argument-parser",
      from: "1.8.2",
    ),
    .package(
      url: "https://github.com/SimplyDanny/SwiftLintPlugins.git",
      from: "0.65.0",
    ),
  ],
  targets: [
    .target(
      name: "CSyphon",
      path: "Sources/CSyphon",
      publicHeadersPath: "include",
      cSettings: [
        .unsafeFlags([
          "-fobjc-arc",
          "-I", "Vendor",
          "-Wno-nullability-completeness",
        ]),
      ],
      linkerSettings: [
        .linkedFramework("AppKit"),
        .linkedFramework("CoreFoundation"),
        .linkedFramework("IOSurface"),
        .linkedFramework("Metal"),
      ],
    ),
    .target(
      name: "SnapSyphonCore",
      dependencies: ["CSyphon"],
      linkerSettings: [
        .linkedFramework("AVFoundation"),
        .linkedFramework("CoreImage"),
        .linkedFramework("CoreMedia"),
        .linkedFramework("CoreVideo"),
        .linkedFramework("Metal"),
      ],
      plugins: [
        .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins"),
      ],
    ),
    .target(
      name: "SnapSyphonCLI",
      dependencies: [
        "SnapSyphonCore",
        .product(
          name: "ArgumentParser",
          package: "swift-argument-parser",
        ),
      ],
      plugins: [
        .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins"),
      ],
    ),
    .executableTarget(
      name: "SnapSyphon",
      dependencies: ["SnapSyphonCLI"],
      plugins: [
        .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins"),
      ],
    ),
    .testTarget(
      name: "SnapSyphonCoreTests",
      dependencies: ["SnapSyphonCore"],
      plugins: [
        .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins"),
      ],
    ),
    .testTarget(
      name: "SnapSyphonCLITests",
      dependencies: ["SnapSyphonCLI"],
      plugins: [
        .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins"),
      ],
    ),
  ],
)
