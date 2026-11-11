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
        .package(url: "https://github.com/lumi-softworks/LumiLogging.git", from: "1.0.1"),
        .package(url: "https://github.com/lumi-softworks/LumiKernel.git", from: "1.1.0"),
        .package(url: "https://github.com/lumi-softworks/LumiSettings.git", from: "1.1.0"),
        .package(url: "https://github.com/lumi-softworks/LumiUI.git", from: "1.13.1"),
        .package(url: "https://github.com/lumi-softworks/LumiProviders.git", from: "1.22.0"),
        .package(url: "https://github.com/lumi-softworks/KitAgentTool.git", from: "1.0.0"),
        .package(url: "https://github.com/lumi-softworks/ProviderToolManager.git", from: "1.0.0")
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
                .product(name: "ProviderLogo", package: "LumiProviders"),
                .product(name: "ProviderStorage", package: "LumiProviders"),
                .product(name: "KitAgentTool", package: "KitAgentTool"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
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
                .product(name: "ProviderDocsView", package: "LumiProviders"),
                .product(name: "ProviderLogo", package: "LumiProviders"),
                .product(name: "ProviderStorage", package: "LumiProviders"),
                .product(name: "KitAgentTool", package: "KitAgentTool"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager")
            ],
            path: "Tests/PluginCaffeinateTests"
        )
    ]
)
