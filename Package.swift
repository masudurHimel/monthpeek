// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "MonthPeek",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "MonthPeek",
            path: "Sources/MonthPeek",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "MonthPeekTests",
            dependencies: ["MonthPeek"],
            path: "Tests/MonthPeekTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
