// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Walter",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "Walter", targets: ["Walter"]),
        .executable(name: "WalterHelper", targets: ["WalterHelper"]),
    ],
    targets: [
        .target(name: "SMCKit", linkerSettings: [.linkedFramework("IOKit")]),
        .target(name: "HelperInterface"),
        .executableTarget(name: "WalterHelper", dependencies: ["SMCKit", "HelperInterface"]),
        .executableTarget(name: "Walter", dependencies: ["SMCKit", "HelperInterface"]),
    ]
)
