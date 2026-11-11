// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiPluginCaffeinate",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(
            name: "PluginCaffeinate",
            targets: ["PluginCaffeinate"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiLogging.git", from: "1.0.1"),
        .package(url: "https://github.com/CofficLab/LumiKernel.git", from: "1.1.0"),
        .package(url: "https://github.com/CofficLab/LumiSettings.git", from: "1.1.0"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.13.1"),
        .package(url: "https://github.com/CofficLab/LumiProviders.git", from: "1.22.0")
    ],
    targets: [
        .target(
            name: "PluginCaffeinate",
            dependencies: [
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderSettingView", package: "LumiSettings"),
                .product(name: "ProviderMenuBar", package: "LumiProviders"),
                .product(name: "ProviderDocsView", package: "LumiProviders"),
                .product(name: "LumiUI", package: "LumiUI")
            ],
            path: "Sources/PluginCaffeinate",
            resources: [.process("../../Resources/Caffeinate.xcstrings")]
        ),
        .testTarget(
            name: "PluginCaffeinateTests",
            dependencies: [
                "PluginCaffeinate",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderSettingView", package: "LumiSettings"),
                .product(name: "ProviderMenuBar", package: "LumiProviders"),
                .product(name: "ProviderDocsView", package: "LumiProviders")
            ],
            path: "Tests/PluginCaffeinateTests"
        )
    ]
)
