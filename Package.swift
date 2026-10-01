// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CoverLetterFiller",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "CoverLetterFiller", targets: ["CoverLetterFiller"]),
    ],
    targets: [
        .executableTarget(
            name: "CoverLetterFiller",
            path: "Sources/CoverLetterFiller"
        ),
        .testTarget(
            name: "CoverLetterFillerTests",
            dependencies: ["CoverLetterFiller"],
            path: "Tests/CoverLetterFillerTests"
        ),
    ]
)
