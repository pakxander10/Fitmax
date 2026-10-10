// swift-tools-version: 5.9
import PackageDescription

// Compiles the app's sources as a macOS-testable library so `swift test` runs
// without a simulator. The shipping app is FitQuest.xcodeproj; both build the
// same FitQuest/ folder.
let package = Package(
    name: "FitQuest",
    platforms: [.iOS(.v17), .macOS(.v14)],
    targets: [
        .target(
            name: "FitQuest",
            path: "FitQuest",
            exclude: ["App/FitQuestApp.swift", "Secrets.plist", "Secrets.example.plist"]
        ),
        .testTarget(name: "FitQuestTests", dependencies: ["FitQuest"], path: "FitQuestTests"),
    ]
)
