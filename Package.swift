// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KnowWhereAmICore",
    platforms: [.macOS(.v14), .iOS("27.0")],
    products: [.library(name: "KnowWhereAmICore", targets: ["KnowWhereAmICore"])],
    targets: [
        .target(name: "KnowWhereAmICore"),
        .testTarget(name: "KnowWhereAmICoreTests", dependencies: ["KnowWhereAmICore"])
    ]
)
