// swift-tools-version: 5.9
import PackageDescription

// The same Foundation model is compiled by Xcode and tested without an iOS SDK.
let package = Package(
    name: "SpacesCore",
    products: [.library(name: "SpacesCore", targets: ["SpacesCore"])],
    targets: [
        .target(name: "SpacesCore", path: "Spaces",
                exclude: ["SpacesApp.swift", "ContentView.swift", "ConversationRow.swift", "ChatTheme.swift", "SpaceHomeView.swift", "Assets.xcassets"],
                sources: ["ChatListModel.swift"]),
        .testTarget(name: "SpacesCoreTests", dependencies: ["SpacesCore"], path: "Tests")
    ]
)
