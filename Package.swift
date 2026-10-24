// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "BlowMyFans",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "BlowMyFans", targets: ["BlowMyFans"]),
        .executable(name: "BlowMyFansHelper", targets: ["BlowMyFansHelper"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.10.0"),
    ],
    targets: [
        .target(name: "SMCKit", linkerSettings: [.linkedFramework("IOKit")]),
        .target(name: "HelperInterface"),
        .executableTarget(name: "BlowMyFansHelper", dependencies: ["SMCKit", "HelperInterface"]),
        .executableTarget(
            name: "BlowMyFans",
            dependencies: ["SMCKit", "HelperInterface", .product(name: "Sparkle", package: "Sparkle")],
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
        ),
    ]
)
