// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TagReportingCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v13),
    ],
    products: [
        .library(name: "TagReportingCore", targets: ["TagReportingCore"]),
    ],
    targets: [
        .target(
            name: "TagReportingCore",
            path: "Sources/TagReportingCore"
        ),
        .testTarget(
            name: "TagReportingCoreTests",
            dependencies: ["TagReportingCore"],
            path: "Tests/TagReportingCoreTests"
        ),
    ]
)
